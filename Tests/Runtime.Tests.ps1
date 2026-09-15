BeforeAll {
    $script:RuntimePath = Join-Path $PSScriptRoot '..\Scripts\Copy-OSDLogToFileShare.ps1'
    $Tokens = $null
    $Errors = $null
    $script:RuntimeAst = [System.Management.Automation.Language.Parser]::ParseFile($script:RuntimePath, [ref]$Tokens, [ref]$Errors)
    foreach ($Definition in $script:RuntimeAst.FindAll({
        param($Node)
        $Node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $false)) {
        . ([scriptblock]::Create($Definition.Extent.Text))
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $script:InboxMappingCommand = Get-Command New-SmbMapping
    $script:InboxMappingParameterSets = $script:InboxMappingCommand.ParameterSets
}

Describe 'Runtime behavior' {
BeforeEach {
    Set-StrictMode -Version 2.0
    $script:Version = '1.0.0'
    $script:Component = 'CopyOSDLogs'
    $script:LogPath = Join-Path $TestDrive 'CopyOSDLogs.log'
    $Secret = New-Object System.Security.SecureString
    'test-secret-only'.ToCharArray() | ForEach-Object { $Secret.AppendChar($_) }
    $script:Credential = New-Object System.Management.Automation.PSCredential ('CONTOSO\test-user', $Secret)
    $script:WindowsRoot = Join-Path $TestDrive 'Windows'
    $script:ProgramDataRoot = Join-Path $TestDrive 'ProgramData'
    $script:SystemDriveRoot = $TestDrive
    $script:AllowUnencryptedSmb = $false
    $script:AllowUnverifiedSmb = $false
    $script:AllowNtlmV2 = $false
    $script:MinimumSmbDialect = 'SMB3'
    $script:Variables = @{
        '_SMSTSInWinPE' = 'false'
        '_SMSTSLogPath' = $TestDrive
        OSDComputerName = 'TEST-PC'
        OSDLogFileShare = '\\fileserver.contoso.com\OSDLogs$\Logs'
        OSDLogUserName = $script:Credential.UserName
        OSDLogPassword = $script:Credential.GetNetworkCredential().Password
        OSDisk = ''
    }
    $script:TaskSequenceEnvironment = [pscustomobject]@{}
    $script:TaskSequenceEnvironment | Add-Member ScriptMethod Value { param($Name) return $script:Variables[$Name] }
}

Describe 'Collection and archive behavior' {
    It 'accepts an initially empty source list and missing optional paths' {
        $Sources = New-Object System.Collections.ArrayList
        Add-LogSource -List $Sources -Name Missing -Path ''
        $Sources.Count | Should -Be 1
        $Sources[0].Path | Should -Be ''
    }

    It 'copies directory contents literally including bracketed names and nested files' {
        $SourceRoot = Join-Path $TestDrive 'source[1]'
        [void](New-Item -ItemType Directory -Path (Join-Path $SourceRoot 'nested') -Force)
        Set-Content -LiteralPath (Join-Path $SourceRoot 'smsts[1].log') -Value 'first'
        Set-Content -LiteralPath (Join-Path $SourceRoot 'nested\more.log') -Value 'second'
        $Manifest = New-Object System.Collections.ArrayList
        $Source = [pscustomobject]@{ Name = 'TS'; Path = $SourceRoot; Recurse = $true }
        Copy-LogSource -Source $Source -DestinationRoot $TestDrive -ManifestItems $Manifest
        $Manifest[0].Status | Should -Be 'Collected'
        Get-Content -LiteralPath (Join-Path $TestDrive 'TS\smsts[1].log') | Should -Be 'first'
        Get-Content -LiteralPath (Join-Path $TestDrive 'TS\nested\more.log') | Should -Be 'second'
    }

    It 'does not copy child directories for a nonrecursive source' {
        $SourceRoot = Join-Path $TestDrive 'flat-source'
        [void](New-Item -ItemType Directory -Path (Join-Path $SourceRoot 'nested') -Force)
        Set-Content -LiteralPath (Join-Path $SourceRoot 'one.log') -Value 'one'
        Set-Content -LiteralPath (Join-Path $SourceRoot 'nested\two.log') -Value 'two'
        $Manifest = New-Object System.Collections.ArrayList
        Copy-LogSource -Source ([pscustomobject]@{Name='Flat';Path=$SourceRoot;Recurse=$false}) -DestinationRoot $TestDrive -ManifestItems $Manifest
        Test-Path -LiteralPath (Join-Path $TestDrive 'Flat\one.log') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $TestDrive 'Flat\nested') | Should -BeFalse
    }

    It 'excludes the staging ancestor when a log source contains the working directory' {
        $SourceRoot = Join-Path $TestDrive 'parent-source'
        $ContentRoot = Join-Path $SourceRoot 'pending\content'
        [void](New-Item -ItemType Directory -Path $ContentRoot -Force)
        Set-Content -LiteralPath (Join-Path $SourceRoot 'smsts.log') -Value 'log'
        $Manifest = New-Object System.Collections.ArrayList
        Copy-LogSource -Source ([pscustomobject]@{Name='TS';Path=$SourceRoot;Recurse=$true}) -DestinationRoot $ContentRoot -ManifestItems $Manifest
        Test-Path -LiteralPath (Join-Path $ContentRoot 'TS\smsts.log') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $ContentRoot 'TS\pending') | Should -BeFalse
    }

    It 'records missing and failed sources without returning warning strings as results' {
        $Manifest = New-Object System.Collections.ArrayList
        Copy-LogSource -Source ([pscustomobject]@{Name='Absent';Path='';Recurse=$true}) -DestinationRoot $TestDrive -ManifestItems $Manifest
        $Manifest[0].Status | Should -Be 'NotFound'
        $File = Join-Path $TestDrive 'denied.log'
        Set-Content $File 'content'
        Mock Copy-Item { throw 'Access denied' }
        $Output = @(Copy-LogSource -Source ([pscustomobject]@{Name='Denied';Path=$File;Recurse=$false}) -DestinationRoot $TestDrive -ManifestItems $Manifest)
        $Output.Count | Should -Be 0
        $Manifest[1].Status | Should -Be 'Error'
    }

    It 'writes a real ZIP containing the manifest and collected content' {
        $Content = Join-Path $TestDrive 'archive-content'
        [void](New-Item -ItemType Directory -Path $Content -Force)
        Set-Content -LiteralPath (Join-Path $Content 'sample.log') -Value 'diagnostic'
        $ComputerName = 'TEST'
        Export-Manifest -Path (Join-Path $Content 'Manifest.json') -ComputerName $ComputerName -Extended $false -ManifestItems @()
        $Archive = Join-Path $TestDrive 'result.zip'
        Invoke-ArchiveCreation -SourceFolder $Content -ArchivePath $Archive
        $Zip = [IO.Compression.ZipFile]::OpenRead($Archive)
        try {
            $Zip.Entries.FullName | Should -Contain 'Manifest.json'
            $Zip.Entries.FullName | Should -Contain 'sample.log'
        } finally { $Zip.Dispose() }
        $Manifest = Get-Content (Join-Path $Content 'Manifest.json') -Raw | ConvertFrom-Json
        $Manifest.Version | Should -Be '1.0.0'
        @($Manifest.Items).Count | Should -Be 0
    }

    It 'resolves standard source placeholders to the selected operating system volume' {
        $Sources = New-Object System.Collections.ArrayList
        Add-LogSource -List $Sources -Name CCM -Path '%WINDIR%\CCM\Logs'
        Add-LogSource -List $Sources -Name Intune -Path '%ProgramData%\Microsoft\IntuneManagementExtension\Logs'
        $Sources[0].Path | Should -Be (Join-Path $script:WindowsRoot 'CCM\Logs')
        $Sources[1].Path | Should -Be (Join-Path $script:ProgramDataRoot 'Microsoft\IntuneManagementExtension\Logs')
    }
}

Describe 'Task Sequence environment and input' {
    It 'prefers an explicit false WinPE variable over the MiniNT fallback' {
        Mock Test-Path { $true }
        Test-WindowsPe | Should -BeFalse
    }
    It 'prefers an explicit true WinPE variable' {
        $script:Variables['_SMSTSInWinPE'] = 'true'
        Mock Test-Path { $false }
        Test-WindowsPe | Should -BeTrue
    }
    It 'uses MiniNT when the WinPE variable is absent or malformed' -TestCases @(@{Value=''}, @{Value='invalid'}) {
        param($Value)
        $script:Variables['_SMSTSInWinPE'] = $Value
        Mock Test-Path { $true } -ParameterFilter { $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT' }
        Test-WindowsPe | Should -BeTrue
    }
    It 'uses X as the final WinPE fallback' {
        $script:Variables['_SMSTSInWinPE'] = ''
        Mock Test-Path { $false }
        $Previous = $env:SystemDrive
        try {
            $env:SystemDrive = 'X:'
            Test-WindowsPe | Should -BeTrue
        } finally { $env:SystemDrive = $Previous }
    }
    It 'uses OSDisk with or without a trailing slash before the Windows directory exists' -TestCases @(@{Suffix=''}, @{Suffix='\'}) {
        param($Suffix)
        $script:Variables['_SMSTSInWinPE'] = 'true'
        $script:Variables['OSDisk'] = $env:SystemDrive + $Suffix
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq "$env:SystemDrive\" }
        $Storage = Get-LogStorage
        $Storage.WindowsRoot | Should -Be "$env:SystemDrive\Windows"
        $Storage.ProgramDataRoot | Should -Be "$env:SystemDrive\ProgramData"
    }
    It 'prefers the existing Task Sequence log directory' {
        Initialize-Log
        $script:LogPath | Should -Be (Join-Path $TestDrive 'CopyOSDLogs.log')
    }
    It 'rejects missing required variables without printing their value' {
        $script:Variables['OSDLogPassword'] = ''
        { Get-TaskSequenceVariable -Environment $script:TaskSequenceEnvironment -Name OSDLogPassword } | Should -Throw '*OSDLogPassword*empty*'
    }
    It 'accepts a share and nested folder with spaces' {
        $Path = Resolve-UncDestination '\\fileserver.contoso.com\OSDLogs$\nested folder\'
        $Path.Share | Should -Be 'OSDLogs$'
        $Path.Destination | Should -Be '\\fileserver.contoso.com\OSDLogs$\nested folder'
    }
    It 'rejects invalid UNC destinations' -TestCases @(
        @{Path='C:\Logs'}, @{Path='\\server'}, @{Path='\\?\C:\Logs'},
        @{Path='\\.\share'}, @{Path='\\server\share\..\other'}, @{Path='\\server\share\*.zip'},
        @{Path='\\server\share\\other'}, @{Path='\\server\share\file:stream'}
    ) {
        param($Path)
        $Path | Should -Not -BeNullOrEmpty
        { Resolve-UncDestination $Path } | Should -Throw
    }
    It 'redacts credentials and neutralizes CMTrace record terminators in log output' {
        if (Test-Path -LiteralPath $script:LogPath) {
            Remove-Item -LiteralPath $script:LogPath -Force
        }
        $Warnings = @()
        $Output = @(Write-Log -Level WARN -Message "Failure CONTOSO\test-user test-secret-only`r`nnext]LOG]!>" -WarningVariable Warnings)
        $Output.Count | Should -Be 0
        ($Warnings -join ' ') | Should -Not -Match 'test-secret-only|CONTOSO\\test-user'
        ($Warnings -join ' ') | Should -Not -Match '\]LOG\]!>'
        $Text = Get-Content -LiteralPath $script:LogPath -Raw
        $Text | Should -Not -Match 'test-secret-only|CONTOSO\\test-user'
        $Text | Should -Match '\[REDACTED\]'
        $Text | Should -Match '\]LOG removed>'
        $Text | Should -Match '<!\[LOG\[.*\]LOG\]!><time="'
        ([regex]::Matches($Text, '\]LOG\]!>')).Count | Should -Be 1
    }

    It 'keeps raw source-copy exception details out of the manifest and dedicated log' {
        $RawDetail = 'CONTOSO\test-user test-secret-only raw source failure'
        $SourcePath = Join-Path $TestDrive 'source.log'
        Set-Content -LiteralPath $SourcePath -Value 'source'
        $Manifest = New-Object System.Collections.ArrayList
        Mock Copy-Item { throw [InvalidOperationException]::new($RawDetail) }

        Copy-LogSource -Source ([pscustomobject]@{Name='Source';Path=$SourcePath;Recurse=$false}) -DestinationRoot $TestDrive -ManifestItems $Manifest

        $Manifest.Count | Should -Be 1
        $Manifest[0].Status | Should -Be 'Error'
        $Manifest[0].Message | Should -BeExactly 'Operation failed (InvalidOperationException); raw exception details are omitted to protect credentials.'
        $Manifest[0].Message | Should -Not -Match 'test-user|test-secret-only|raw source failure'
        (Get-Content -LiteralPath $script:LogPath -Raw) | Should -Not -Match 'test-user|test-secret-only|raw source failure'
    }
    It 'appends every CMTrace entry without losing rapid successive writes' {
        $script:LogPath = Join-Path $TestDrive ('append-' + [guid]::NewGuid().ToString('N') + '.log')
        $Warnings = @()
        foreach ($Index in 1..200) {
            Write-Log -Message "Entry $Index" -WarningVariable +Warnings
        }
        $Warnings.Count | Should -Be 0
        $Lines = [IO.File]::ReadAllLines($script:LogPath)
        $Lines.Count | Should -Be 200
        $Lines[199] | Should -Match 'Entry 200'
    }
}

Describe 'SMB inspection policy' {
    BeforeEach {
        $script:Connection = [pscustomobject]@{ShareName='OSDLogs$'; Credential='CONTOSO\test-user'; Dialect='3.1.1'; Signed=$true; Encrypted=$true}
        Mock Get-SmbConnection { $script:Connection }
        $script:Inspection = @{Server='fileserver.contoso.com';Share='OSDLogs$';UserName='CONTOSO\test-user';MinimumDialect='SMB3';AllowUnencrypted=$false;AllowUnverified=$false}
    }
    It 'accepts an encrypted SMB3 connection without success-stream logging' {
        @(Confirm-SmbConnectionSecurity @script:Inspection).Count | Should -Be 0
    }
    It 'treats encryption as integrity protection even when Signed is false' {
        $script:Connection.Signed = $false
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Not -Throw
    }
    It 'fails closed when inspection is unavailable unless explicitly waived' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Get-SmbConnection' }
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Throw '*inspection*unavailable*'
        $script:Inspection.AllowUnverified = $true
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Not -Throw
    }
    It 'fails closed for inspection errors by default' {
        Mock Get-SmbConnection { throw 'Access denied' }
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Throw '*Unable to verify*'
    }
    It 'does not log raw inspection diagnostics under an explicit waiver' {
        $RawDetail = 'CONTOSO\test-user test-secret-only raw inspection failure'
        Mock Get-SmbConnection { throw [InvalidOperationException]::new($RawDetail) }
        $script:Inspection.AllowUnverified = $true
        $Warnings = @()

        Confirm-SmbConnectionSecurity @script:Inspection -WarningVariable +Warnings

        ($Warnings -join ' ') | Should -Not -Match 'test-user|test-secret-only|raw inspection failure'
        (Get-Content -LiteralPath $script:LogPath -Raw) | Should -Not -Match 'test-user|test-secret-only|raw inspection failure'
        (Get-Content -LiteralPath $script:LogPath -Raw) | Should -Match 'Operation failed \(InvalidOperationException\)'
    }
    It 'does not accept another credential session as proof' {
        $script:Connection.Credential = 'CONTOSO\someone-else'
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Throw '*Unable to verify*'
    }
    It 'requires explicit SMB2 and unencrypted compatibility flags' {
        $script:Connection.Dialect = '2.1'
        $script:Connection.Encrypted = $false
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Throw '*dialect*'
        $script:Inspection.MinimumDialect = 'SMB2'
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Throw '*privacy*'
        $script:Inspection.AllowUnencrypted = $true
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Not -Throw
    }
    It 'never permits an observed SMB1 connection even with all compatibility flags' {
        $script:Connection.Dialect = '1.0'
        $script:Inspection.MinimumDialect = 'SMB2'
        $script:Inspection.AllowUnencrypted = $true
        $script:Inspection.AllowUnverified = $true
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Throw '*dialect*'
    }
    It 'does not waive a known integrity failure' {
        $script:Connection.Signed = $false
        $script:Connection.Encrypted = $false
        $script:Inspection.AllowUnencrypted = $true
        $script:Inspection.AllowUnverified = $true
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Throw '*integrity*'
    }
    It 'requires explicit unverified compatibility for absent properties' {
        $script:Connection.PSObject.Properties.Remove('Signed')
        $script:Connection.PSObject.Properties.Remove('Encrypted')
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Throw '*cannot be verified*'
        $script:Inspection.AllowUnverified = $true
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Not -Throw
    }
    It 'does not waive known privacy failure when inspection is partly unavailable' {
        $script:Connection.PSObject.Properties.Remove('Dialect')
        $script:Connection.Encrypted = $false
        $script:Inspection.AllowUnverified = $true
        { Confirm-SmbConnectionSecurity @script:Inspection } | Should -Throw '*privacy*'
    }
}

Describe 'SMB connection controls and upload' {
    BeforeEach {
        $Parameters = @{}
        foreach ($Name in @('BlockNTLM', 'RequireIntegrity', 'RequirePrivacy', 'Credential')) {
            if ($script:InboxMappingCommand.Parameters.ContainsKey($Name)) { $Parameters[$Name] = $true }
        }
        $script:MappingCommand = [pscustomobject]@{Parameters=$Parameters}
        $script:AllowNtlmV2 = -not $Parameters.ContainsKey('BlockNTLM')
        Mock Get-Command { $script:MappingCommand } -ParameterFilter { $Name -eq 'New-SmbMapping' }
        Mock Get-ItemProperty { [pscustomobject]@{LmCompatibilityLevel=5} } -ParameterFilter { $Name -eq 'LmCompatibilityLevel' }
        Mock Test-TcpPort { $true }
        Mock Get-SmbMapping { @() }
        Mock New-SmbMapping {}
        Mock Remove-SmbMapping {}
        Mock New-PSDrive {}
        Mock Remove-PSDrive {}
        Mock Confirm-SmbConnectionSecurity {}
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -like '\\fileserver.contoso.com\*' }
        Mock Copy-Item {}
        Mock Get-Item { [pscustomobject]@{Length=100} }
        $script:Upload = @{ArchivePath=(Join-Path $TestDrive 'logs.zip');DestinationShare='\\fileserver.contoso.com\OSDLogs$\Logs';Credential=$script:Credential;TimeoutSeconds=5}
    }
    It 'requests integrity privacy and NTLM blocking without conflicting credential parameter sets' {
        $script:MappingCommand.Parameters['BlockNTLM'] = $true
        $script:AllowNtlmV2 = $false
        $Option = Get-SmbMappingOption -RemotePath '\\fileserver.contoso.com\OSDLogs$' -Credential $script:Credential
        $Option.RequireIntegrity | Should -BeTrue
        $Option.RequirePrivacy | Should -BeTrue
        $Option.BlockNTLM | Should -BeTrue
        $Option.ContainsKey('Credential') | Should -BeFalse
        $Option.UserName | Should -Be 'CONTOSO\test-user'
    }
    It 'builds arguments supported by one real inbox mapping parameter set' {
        $Command = $script:InboxMappingCommand
        $script:MappingCommand = $Command
        if (-not $Command.Parameters.ContainsKey('BlockNTLM')) { $script:AllowNtlmV2 = $true }
        $Option = Get-SmbMappingOption -RemotePath '\\server\share' -Credential $script:Credential
        $CompatibleSets = @($script:InboxMappingParameterSets | Where-Object {
            $Names = $_.Parameters.Name
            @($Option.Keys | Where-Object { $Names -notcontains $_ }).Count -eq 0
        })
        $CompatibleSets.Count | Should -BeGreaterThan 0
    }
    It 'requires explicit NTLMv2 compatibility on older platforms' {
        $script:MappingCommand.Parameters.Remove('BlockNTLM')
        $script:MappingCommand.Parameters['Credential'] = $true
        $script:AllowNtlmV2 = $false
        { Get-SmbMappingOption -RemotePath '\\server\share' -Credential $script:Credential } | Should -Throw '*NTLM blocking*'
        $script:AllowNtlmV2 = $true
        $Option = Get-SmbMappingOption -RemotePath '\\server\share' -Credential $script:Credential
        $Option.Credential | Should -Be $script:Credential
        $Option.ContainsKey('BlockNTLM') | Should -BeFalse
    }
    It 'permits unencrypted compatibility without disabling integrity requirements' {
        $script:AllowUnencryptedSmb = $true
        $Option = Get-SmbMappingOption -RemotePath '\\server\share' -Credential $script:Credential
        $Option.RequireIntegrity | Should -BeTrue
        $Option.ContainsKey('RequirePrivacy') | Should -BeFalse
    }
    It 'requires an explicit waiver when a requested per-connection control is unavailable' {
        $script:MappingCommand.Parameters.Remove('RequirePrivacy')
        { Get-SmbMappingOption -RemotePath '\\server\share' -Credential $script:Credential } | Should -Throw '*RequirePrivacy*'
        $script:AllowUnverifiedSmb = $true
        { Get-SmbMappingOption -RemotePath '\\server\share' -Credential $script:Credential } | Should -Not -Throw
    }
    It 'rejects NTLMv2 compatibility if client policy permits legacy authentication' {
        $script:AllowNtlmV2 = $true
        Mock Get-ItemProperty { [pscustomobject]@{LmCompatibilityLevel=2} } -ParameterFilter { $Name -eq 'LmCompatibilityLevel' }
        { Get-SmbMappingOption -RemotePath '\\server\share' -Credential $script:Credential } | Should -Throw '*3 through 5*'
    }
    It 'requires both explicit fallback flags and NTLMv2-only policy when mapping cmdlets are absent' {
        $script:MappingCommand = $null
        $script:AllowNtlmV2 = $false
        { Send-Archive @script:Upload } | Should -Throw '*AllowUnverifiedSmb*'
        $script:AllowUnverifiedSmb = $true
        { Send-Archive @script:Upload } | Should -Throw '*AllowNtlmV2*'
        $script:AllowNtlmV2 = $true
        Send-Archive @script:Upload | Should -Be '\\fileserver.contoso.com\OSDLogs$\Logs\logs.zip'
        Should -Invoke New-PSDrive -Times 1 -Exactly
        Should -Invoke Remove-PSDrive -Times 1 -Exactly
    }
    It 'fails before connection when TCP 445 is unavailable' {
        Mock Test-TcpPort { $false }
        { Send-Archive @script:Upload } | Should -Throw '*TCP 445*'
        Should -Invoke Test-TcpPort -Times 1 -Exactly -ParameterFilter { $Port -eq 445 -and $TimeoutSeconds -eq 5 }
        Should -Invoke New-SmbMapping -Times 0 -Exactly
    }
    It 'does not fall back after a mapping failure' {
        Mock New-SmbMapping { throw 'Wrong credentials' }
        { Send-Archive @script:Upload } | Should -Throw '*Wrong credentials*'
        Should -Invoke New-PSDrive -Times 0 -Exactly
        Should -Invoke Remove-SmbMapping -Times 0 -Exactly
    }
    It 'does not remove or reuse an existing destination mapping' {
        Mock Get-SmbMapping { [pscustomobject]@{RemotePath='\\fileserver.contoso.com\OSDLogs$'} }
        { Send-Archive @script:Upload } | Should -Throw '*already exists*'
        Should -Invoke New-SmbMapping -Times 0 -Exactly
        Should -Invoke Remove-SmbMapping -Times 0 -Exactly
    }
    It 'removes its own mapping when byte-size verification fails' {
        Mock Get-Item { [pscustomobject]@{Length=99} } -ParameterFilter { $LiteralPath -like '\\fileserver.contoso.com\*' }
        { Send-Archive @script:Upload } | Should -Throw '*size mismatch*'
        Should -Invoke Remove-SmbMapping -Times 1 -Exactly
    }
    It 'rejects a missing destination and removes its own mapping' {
        Mock Test-Path { $false } -ParameterFilter { $LiteralPath -like '\\fileserver.contoso.com\*' }
        { Send-Archive @script:Upload } | Should -Throw '*folder does not exist*'
        Should -Invoke Remove-SmbMapping -Times 1 -Exactly
    }
    It 'rejects access denial or interrupted upload and removes its own mapping' {
        Mock Copy-Item { throw 'Upload interrupted' }
        { Send-Archive @script:Upload } | Should -Throw '*interrupted*'
        Should -Invoke Remove-SmbMapping -Times 1 -Exactly
    }
    It 'returns only the remote path on successful byte-size verification' {
        $Output = @(Send-Archive @script:Upload)
        $Output.Count | Should -Be 1
        $Output[0] | Should -Be '\\fileserver.contoso.com\OSDLogs$\Logs\logs.zip'
        Should -Invoke New-SmbMapping -Times 1 -Exactly -ParameterFilter { $RequireIntegrity -and $RequirePrivacy }
    }
}

Describe 'Orchestration with mocked Task Sequence and network' {
    AfterEach {
        [IO.File]::ReadAllText($script:LogPath) | Should -Match 'Script exit code: [01]'
    }
    BeforeEach {
        $Statements = $script:RuntimeAst.EndBlock.Statements
        $Start = ($Statements | Where-Object { $_.Extent.Text -eq '$ExitCode = 1' } | Select-Object -First 1).Extent.StartOffset
        $End = ($Statements | Where-Object { $_ -is [System.Management.Automation.Language.ExitStatementAst] } | Select-Object -Last 1).Extent.StartOffset
        $script:MainBody = [scriptblock]::Create($script:RuntimeAst.Extent.Text.Substring($Start, $End - $Start) + "`n" + '$script:ObservedExitCode = $ExitCode')
        $script:RetryCount = 3
        $script:RetryDelaySeconds = 0
        $script:TimeoutSeconds = 5
        $script:IncludeExtendedLogs = $false
        $RuntimeRoot = Join-Path $TestDrive ('Runtime-' + [guid]::NewGuid().ToString('N'))
        $script:WindowsRoot = Join-Path $RuntimeRoot 'Windows'
        $script:ProgramDataRoot = Join-Path $RuntimeRoot 'ProgramData'
        $script:SystemDriveRoot = $RuntimeRoot
        $script:Pending = Join-Path $RuntimeRoot 'PendingOSDLogs'
        $LogFolder = Join-Path $RuntimeRoot 'TaskSequence'
        [void](New-Item -Path $LogFolder -ItemType Directory -Force)
        $script:Variables['_SMSTSLogPath'] = $LogFolder
        Mock Get-TaskSequenceEnvironment { $script:TaskSequenceEnvironment }
        Mock Get-LogStorage { [pscustomobject]@{
            PendingRoot=$script:Pending;WindowsRoot=$script:WindowsRoot
            ProgramDataRoot=$script:ProgramDataRoot;SystemDriveRoot=$script:SystemDriveRoot
        } }
        Mock Start-Sleep {}
        Mock Send-Archive { '\\fileserver.contoso.com\OSDLogs$\Logs\logs.zip' }
        [void](New-Item -Path (Join-Path $script:WindowsRoot 'CCM\Logs') -ItemType Directory -Force)
        Set-Content -LiteralPath (Join-Path $script:WindowsRoot 'CCM\Logs\client.log') -Value 'client log'
    }
    It 'collects real files and removes the work folder and local ZIP after mocked success' {
        & $script:MainBody
        $script:ObservedExitCode | Should -Be 0
        @(Get-ChildItem -LiteralPath $script:Pending).Count | Should -Be 0
        Should -Invoke Send-Archive -Times 1 -Exactly
    }
    It 'passes the PSCredential constructed from Task Sequence variables to Send-Archive' {
        $script:Credential = $null
        $script:ObservedCredential = $null
        $script:ObservedScriptCredential = $false
        Remove-Variable -Name Credential -ErrorAction SilentlyContinue
        $script:Variables['OSDLogUserName'] = 'CONTOSO\test-user'
        $script:Variables['OSDLogPassword'] = 'test-secret-only'
        Mock Send-Archive {
            $script:ObservedCredential = $Credential
            $script:ObservedScriptCredential = [object]::ReferenceEquals($Credential, $script:Credential)
            '\\fileserver.contoso.com\OSDLogs$\Logs\logs.zip'
        }

        $Shadow = New-Object System.Management.Automation.PSCredential (
            'CONTOSO\scope-sentinel', (New-Object System.Security.SecureString))
        & {
            # A distinct local credential exposes unqualified references without prompting for credentials.
            Set-Variable -Name Credential -Value $Shadow -Scope Local
            . $script:MainBody
        }

        $script:ObservedExitCode | Should -Be 0
        Should -Invoke Send-Archive -Times 1 -Exactly
        $script:ObservedScriptCredential | Should -BeTrue
        $script:ObservedCredential | Should -BeOfType [System.Management.Automation.PSCredential]
        $script:ObservedCredential.UserName | Should -BeExactly $script:Variables['OSDLogUserName']
        $script:ObservedCredential.Password | Should -BeOfType [System.Security.SecureString]
        # Compared as a boolean so neither value can reach test output.
        ($script:ObservedCredential.GetNetworkCredential().Password -ceq
            $script:Variables['OSDLogPassword']) | Should -BeTrue
    }
    It 'retains a readable local archive and stops after the configured failed attempts' {
        Mock Send-Archive { throw 'Destination unavailable' }
        & $script:MainBody
        $script:ObservedExitCode | Should -Be 1
        Should -Invoke Send-Archive -Times 3 -Exactly
        $Archives = @(Get-ChildItem -LiteralPath $script:Pending -Filter *.zip)
        $Archives.Count | Should -Be 1
        $Zip = [IO.Compression.ZipFile]::OpenRead($Archives[0].FullName)
        try {
            ($Zip.Entries.FullName -replace '\\', '/') | Should -Contain 'Content/CCMLogs/client.log'
            $Entry = $Zip.Entries | Where-Object { ($_.FullName -replace '\\', '/') -eq '_Meta/Manifest.json' }
            $Reader = New-Object IO.StreamReader ($Entry.Open())
            try { $Manifest = $Reader.ReadToEnd() | ConvertFrom-Json } finally { $Reader.Dispose() }
            ($Manifest.Items | Where-Object Name -EQ CCMLogs).Status | Should -Be 'Collected'
            ($Manifest.Items | Where-Object Name -EQ CBS) | Should -BeNullOrEmpty
        } finally { $Zip.Dispose() }
    }
    It 'does not log raw upload exception details' {
        $RawDetail = 'CONTOSO\test-user test-secret-only raw upload failure'
        Mock Send-Archive { throw [InvalidOperationException]::new($RawDetail) }

        & $script:MainBody

        $script:ObservedExitCode | Should -Be 1
        (Get-Content -LiteralPath $script:LogPath -Raw) | Should -Not -Match 'test-user|test-secret-only|raw upload failure'
        (Get-Content -LiteralPath $script:LogPath -Raw) | Should -Match 'Operation failed \(InvalidOperationException\)'
    }
    It 'includes extended sources only when explicitly requested' {
        $script:IncludeExtendedLogs = $true
        Mock Send-Archive { throw 'Destination unavailable' }
        & $script:MainBody
        $ManifestPath = (Get-ChildItem -LiteralPath $script:Pending -Filter Manifest.json -Recurse | Select-Object -First 1).FullName
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        $Manifest.ExtendedCollection | Should -BeTrue
        $Manifest.Items.Name | Should -Contain CBS
        $Manifest.Items.Name | Should -Contain UpgradeRollback
    }
    It 'waits only between unsuccessful attempts' {
        $script:RetryDelaySeconds = 1
        Mock Send-Archive { throw 'Destination unavailable' }
        & $script:MainBody
        Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 1 }
    }
    It 'retains the ZIP and returns failure when post-upload folder cleanup fails' {
        Mock Remove-Item { throw 'Cleanup denied' } -ParameterFilter { $Recurse }
        & $script:MainBody
        $script:ObservedExitCode | Should -Be 1
        @(Get-ChildItem -LiteralPath $script:Pending -Filter *.zip).Count | Should -Be 1
    }
    It 'succeeds after a transient failure without exhausting the retry limit' {
        $script:UploadCalls = 0
        Mock Send-Archive {
            $script:UploadCalls++
            if ($script:UploadCalls -eq 1) { throw 'Transient failure' }
            '\\fileserver.contoso.com\OSDLogs$\Logs\logs.zip'
        }
        & $script:MainBody
        $script:ObservedExitCode | Should -Be 0
        Should -Invoke Send-Archive -Times 2 -Exactly
        @(Get-ChildItem -LiteralPath $script:Pending).Count | Should -Be 0
    }
}
}
