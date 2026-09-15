BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    $script:ProductionScript = Get-Content (Join-Path $script:Root 'Scripts\Copy-OSDLogToFileShare.ps1') -Raw
    $script:Ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $script:ProductionScript, [ref]$null, [ref]$null)
}
Describe 'Repository contract' {
    It 'keeps one matching three-part numeric version in the script and manifest' {
        $VersionMatch = [regex]::Match($script:ProductionScript, '(?m)^\$script:Version\s*=\s*''(\d+\.\d+\.\d+)''\s*$')
        $VersionMatch.Success | Should -BeTrue
        $ManifestVersion = (Get-Content (Join-Path $script:Root 'VERSION') -Raw).Trim()
        $ManifestVersion | Should -Match '^\d+\.\d+\.\d+$'
        $VersionMatch.Groups[1].Value | Should -BeExactly $ManifestVersion
    }

    It 'requires Windows PowerShell 5.1 and has strict mode and explicit exit' {
        $script:ProductionScript | Should -Match '(?m)^#Requires -Version 5\.1'
        $script:ProductionScript | Should -Match 'Set-StrictMode'
        $script:Ast.EndBlock.Statements[-1].GetType().Name | Should -Be 'ExitStatementAst'
    }

    It 'uses the ConfigMgr Task Sequence environment and WinPE OSDisk selection' {
        $script:ProductionScript | Should -Match 'Microsoft\.SMS\.TSEnvironment'
        $script:ProductionScript | Should -Match "Value\('OSDisk'\)"
    }

    It 'writes CMTrace format and uses every documented compatibility parameter' {
        $script:ProductionScript | Should -Match '<!\[LOG\['
        foreach ($Parameter in 'AllowUnencryptedSmb', 'AllowUnverifiedSmb', 'MinimumSmbDialect', 'AllowNtlmV2') {
            ([regex]::Matches($script:ProductionScript, $Parameter)).Count | Should -BeGreaterThan 1
        }
    }

    It 'avoids prohibited patterns' {
        $script:ProductionScript | Should -Not -Match 'cmdkey|net\s+use|Win32_Product|Get-WmiObject|\bwmic(?:\.exe)?\b'
    }

    It 'binds the script-scoped credential in the orchestration and leaves no unqualified Credential reference' {
        $Statements = $script:Ast.EndBlock.Statements
        $Start = ($Statements | Where-Object { $_.Extent.Text -eq '$ExitCode = 1' } | Select-Object -First 1).Extent.StartOffset
        $End = ($Statements | Where-Object { $_ -is [System.Management.Automation.Language.ExitStatementAst] } | Select-Object -Last 1).Extent.EndOffset
        $Orchestration = [System.Management.Automation.Language.Parser]::ParseInput(
            $script:Ast.Extent.Text.Substring($Start, $End - $Start), [ref]$null, [ref]$null)

        $Unqualified = @($Orchestration.FindAll({
            param($Node)
            $Node -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $Node.VariablePath.UserPath -ceq 'Credential'
        }, $true))
        $Unqualified.Count | Should -Be 0

        $SendArchive = @($Orchestration.FindAll({
            param($Node)
            $Node -is [System.Management.Automation.Language.CommandAst] -and
            $Node.GetCommandName() -ceq 'Send-Archive'
        }, $true))
        $SendArchive.Count | Should -Be 1
        $SendArchive[0].Extent.Text | Should -Match '-Credential\s+\$script:Credential\b'
    }

    It 'has one matching SHA-256 entry for every maintained file except the checksum manifest' {
        $Names = @()
        foreach ($Line in Get-Content -LiteralPath (Join-Path $script:Root 'CHECKSUMS.txt')) {
            $Entry = [regex]::Match($Line, '^([A-Fa-f0-9]{64})  ([^\\]+)$')
            $Entry.Success | Should -BeTrue
            $Name = $Entry.Groups[2].Value
            $Name | Should -Not -Be 'CHECKSUMS.txt'
            $Path = Join-Path $script:Root $Name.Replace('/', '\')
            Test-Path -LiteralPath $Path -PathType Leaf | Should -BeTrue
            (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash | Should -Be $Entry.Groups[1].Value
            $Names += $Name
        }
        @($Names | Sort-Object -Unique).Count | Should -Be $Names.Count
        $Expected = @(
            Get-ChildItem -LiteralPath $script:Root -Recurse -File -Force |
                Where-Object { $_.Name -notin @('.git', 'CHECKSUMS.txt') -and $_.FullName -notlike "$script:Root\.git\*" } |
                ForEach-Object { $_.FullName.Substring($script:Root.Length + 1).Replace('\', '/') }
        )
        @(Compare-Object ($Expected | Sort-Object) ($Names | Sort-Object)).Count | Should -Be 0
    }

    It 'pins checkout actions, retains publisher verification, and preserves release gates' {
        $ExpectedCheckoutReference = 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1'
        $WorkflowFiles = @(Get-ChildItem -LiteralPath (Join-Path $script:Root '.github\workflows') -Filter '*.yml' -File)
        $WorkflowFiles.Count | Should -BeGreaterThan 0

        foreach ($WorkflowFile in $WorkflowFiles) {
            $WorkflowContent = Get-Content -LiteralPath $WorkflowFile.FullName -Raw
            $WorkflowContent | Should -Match ('(?m)^\s*-\s*uses:\s+' + [regex]::Escape($ExpectedCheckoutReference) + '\s*$')
            $WorkflowContent | Should -Not -Match '(?i)-SkipPublisherCheck'
        }

        $CiWorkflow = Get-Content -LiteralPath (Join-Path $script:Root '.github\workflows\ci.yml') -Raw
        $CiWorkflow | Should -Match '\$ValidationParameters\s*=\s*@\{\}'

        $ReleaseWorkflow = Get-Content -LiteralPath (Join-Path $script:Root '.github\workflows\release.yml') -Raw
        $ReleaseWorkflow | Should -Match "(?m)^\s*-\s*'v\*\.\*\.\*'\s*$"
        foreach ($RequiredText in 'Validate tagged revision', 'Create release archive', 'Get-FileHash', 'Publish GitHub prerelease', 'gh release create', '--verify-tag') {
            $ReleaseWorkflow | Should -Match ([regex]::Escape($RequiredText))
        }

        $ValidationDocumentation = Get-Content -LiteralPath (Join-Path $script:Root 'docs\validation.md') -Raw
        $ValidationDocumentation | Should -Not -Match '(?i)-SkipPublisherCheck'
        $ValidationDocumentation | Should -Match '(?i)do not bypass publisher verification'
    }
}
