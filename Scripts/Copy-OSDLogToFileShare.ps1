#Requires -Version 5.1

<#
.SYNOPSIS
Collects focused ConfigMgr OSD logs, creates a ZIP archive, and uploads it to an authenticated file share.

.DESCRIPTION
Reads OSDLogFileShare, OSDLogUserName, and OSDLogPassword from explicit custom Task Sequence variables.
The script runs as Local System in WinPE or full Windows, collects focused deployment logs, writes Manifest.json, creates a local ZIP archive, uploads it through SMB, verifies the remote file size, and keeps the local archive when upload verification fails.

The script intentionally avoids Network Access Account retrieval, hidden reserved Task Sequence credential variables, legacy command-based credential helpers, and command-line passwords.
Credential variables should be created immediately before the script step and cleared immediately afterward with native Task Sequence steps.

.PARAMETER RetryCount
Number of upload attempts. Default: 3.

.PARAMETER RetryDelaySeconds
Delay between failed upload attempts. Default: 300 seconds.

.PARAMETER TimeoutSeconds
TCP 445 connectivity preflight timeout. Default: 30 seconds.

.PARAMETER IncludeExtendedLogs
Adds Windows setup, servicing, update, and rollback log locations.

.PARAMETER AllowUnencryptedSmb
Explicitly permits SMB without encryption. Signing is still required.

.PARAMETER AllowUnverifiedSmb
Explicitly permits unavailable SMB inspection or per-connection security controls.
Does not permit an observed SMB1 connection or an observed connection without integrity.

.PARAMETER MinimumSmbDialect
Minimum observed dialect: SMB3 by default, or explicitly SMB2.

.PARAMETER AllowNtlmV2
Explicitly permits NTLM authentication only when existing LmCompatibilityLevel is 3 through 5.
Without this switch, per-connection NTLM blocking must be available.
The script never changes Windows authentication or SMB policy.

.EXAMPLE
.\Copy-OSDLogToFileShare.ps1

Collects the standard log profile and uploads the verified archive.

.EXAMPLE
.\Copy-OSDLogToFileShare.ps1 -IncludeExtendedLogs

Collects the standard and extended log profiles for setup, servicing, update, or rollback troubleshooting.

.LINK
https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare

.NOTES
FileName:      Copy-OSDLogToFileShare.ps1
Author:        Claudio Mendes (vartaxe)
Contact:       vartaxe@outlook.com | https://github.com/vartaxe
Version:       1.0.0
Release:       2026-08-03
Target:        Windows PowerShell 5.1 during a ConfigMgr Task Sequence in WinPE or full Windows.
LogFile:       CopyOSDLogs.log
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'The password is supplied at runtime through a hidden ConfigMgr Task Sequence variable, converted immediately to PSCredential, never logged, and not stored in the script.'
)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$RetryCount = 3,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 3600)]
    [int]$RetryDelaySeconds = 300,

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 300)]
    [int]$TimeoutSeconds = 30,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeExtendedLogs,

    [switch]$AllowUnencryptedSmb,

    [switch]$AllowUnverifiedSmb,

    [ValidateSet('SMB2', 'SMB3')]
    [string]$MinimumSmbDialect = 'SMB3',

    [switch]$AllowNtlmV2
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:Version = '1.0.0'
$script:TaskSequenceEnvironment = $null
$script:LogPath = $null
$script:Component = 'CopyOSDLogs'
$script:Credential = $null
$script:WindowsRoot = $env:WINDIR
$script:ProgramDataRoot = $env:ProgramData
$script:SystemDriveRoot = $env:SystemDrive

function Get-TaskSequenceEnvironment {
    try {
        return New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Stop
    }
    catch {
        throw 'Microsoft.SMS.TSEnvironment is unavailable. Run this script inside an active ConfigMgr Task Sequence.'
    }
}

function Get-TaskSequenceVariable {
    param(
        [Parameter(Mandatory = $true)]
        $Environment,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $Value = [string]$Environment.Value($Name)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Task Sequence variable '$Name' is empty."
    }

    return $Value
}

function Initialize-Log {
    $Folder = Join-Path -Path $env:WINDIR -ChildPath 'Temp'

    try {
        $TaskSequenceLogPath = [string]$script:TaskSequenceEnvironment.Value('_SMSTSLogPath')
        if (-not [string]::IsNullOrWhiteSpace($TaskSequenceLogPath)) {
            if (Test-Path -LiteralPath $TaskSequenceLogPath -PathType Container) {
                $Folder = $TaskSequenceLogPath
            }
        }
    }
    catch {
        Write-Verbose 'Cannot read _SMSTSLogPath; using the Windows Temp log location.'
    }

    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        [void](New-Item -Path $Folder -ItemType Directory -Force)
    }

    $script:LogPath = Join-Path -Path $Folder -ChildPath 'CopyOSDLogs.log'
}

function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
    if ($null -ne $script:Credential) {
        foreach ($SensitiveValue in @($script:Credential.UserName, $script:Credential.GetNetworkCredential().Password)) {
            if (-not [string]::IsNullOrEmpty($SensitiveValue)) {
                $Message = $Message.Replace($SensitiveValue, '[REDACTED]')
            }
        }
    }
    $Message = $Message -replace '[\r\n]+', ' ' -replace '\]LOG\]!>', ']LOG removed>'
    try {
        $Type = switch ($Level) {
            'WARN' {
                2
            }
            'ERROR' {
                3
            }
            default {
                1
            }
        }
        $Now = [DateTimeOffset]::Now
        $Bias = [int]$Now.Offset.TotalMinutes
        $Time = $Now.ToString('HH:mm:ss.fff') + ('{0:+0;-0;+0}' -f $Bias)
        $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="{5}" file="">' -f $Message, $Time, $Now.ToString('MM-dd-yyyy'), $script:Component, $Type, [Threading.Thread]::CurrentThread.ManagedThreadId
        [IO.File]::AppendAllText($script:LogPath, $Line + [Environment]::NewLine, [Text.Encoding]::UTF8)
    }
    catch {
        Write-Warning "Unable to write CopyOSDLogs.log ($($_.Exception.GetType().FullName), HResult=$($_.Exception.HResult)); use the Task Sequence output for diagnostics."
    }
    if ($Level -ne 'INFO') {
        Write-Warning "[$Level] $Message"
    }
}

function Get-SafeErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $Exception = $ErrorRecord.Exception
    while ($null -ne $Exception.InnerException) {
        $Exception = $Exception.InnerException
    }

    $KnownMessages = @(
        'Microsoft.SMS.TSEnvironment is unavailable. Run this script inside an active ConfigMgr Task Sequence.',
        "Task Sequence variable 'OSDLogFileShare' is empty.",
        "Task Sequence variable 'OSDLogUserName' is empty.",
        "Task Sequence variable 'OSDLogPassword' is empty.",
        'OSDLogFileShare must be a UNC path with a server and share, without wildcards or device-path syntax.',
        'OSDLogFileShare contains an invalid path component.',
        'SMB inspection is unavailable. An explicit AllowUnverifiedSmb decision is required.',
        'No unambiguous SMB connection was found for the requested share and credential.',
        'SMB integrity is required but the connection is neither signed nor encrypted.',
        'SMB privacy is required but the connection is not encrypted.',
        'Per-connection SMB controls are unavailable. An explicit AllowUnverifiedSmb decision is required.',
        'Per-connection NTLM blocking is unavailable. An explicit AllowNtlmV2 decision with an existing NTLMv2-only client policy is required.',
        'AllowNtlmV2 requires an existing LmCompatibilityLevel of 3 through 5. No policy was changed.',
        'An SMB mapping already exists for the destination. It will not be reused or removed.'
    )
    if ($Exception.Message -cin $KnownMessages) {
        return $Exception.Message
    }
    if ($Exception.Message -match "^SMB dialect '.*' does not meet the required minimum '.*'\.$") {
        return 'SMB dialect does not meet the required minimum.'
    }
    if ($Exception.Message -match '^SMB properties cannot be verified: .+\.$') {
        return 'SMB properties cannot be verified.'
    }
    if ($Exception.Message -match '^Per-connection .+ is unavailable\. An explicit AllowUnverifiedSmb decision is required\.$') {
        return 'A required per-connection SMB control is unavailable.'
    }
    if ($Exception.Message -match '^TCP 445 is not reachable on .+\.$') {
        return 'TCP 445 is not reachable on the configured server.'
    }
    if ($Exception.Message -match '^Destination folder does not exist: .+$') {
        return 'Configured destination folder does not exist.'
    }
    if ($Exception.Message -match '^Remote archive size mismatch\. Local=\d+ Remote=\d+$') {
        return 'Remote archive size verification failed.'
    }
    if ($Exception.Message -match '^Upload failed after (\d+) attempt\(s\)\. Pending local archive retained: .+$') {
        return "Upload failed after $($Matches[1]) attempt(s). Pending local archive retained."
    }

    return "Operation failed ($($Exception.GetType().Name)); raw exception details are omitted to protect credentials."
}

function Test-WindowsPe {
    try {
        $Value = ([string]$script:TaskSequenceEnvironment.Value('_SMSTSInWinPE')).Trim()
        if ($Value -eq 'true') {
            return $true
        }
        if ($Value -eq 'false') {
            return $false
        }
    }
    catch {
        Write-Verbose 'Cannot read _SMSTSInWinPE; using local WinPE detection.'
    }
    if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT') {
        return $true
    }
    return $env:SystemDrive -eq 'X:'
}

function Get-LogStorage {
    $WindowsRoot = $env:WINDIR
    $SystemDriveRoot = $env:SystemDrive
    $ProgramDataRoot = $env:ProgramData
    if (Test-WindowsPe) {
        $OSDisk = ([string]$script:TaskSequenceEnvironment.Value('OSDisk')).Trim().TrimEnd('\')
        if (($OSDisk -match '^[A-Za-z]:$') -and (Test-Path -LiteralPath "$OSDisk\" -PathType Container)) {
            $SystemDriveRoot = $OSDisk
            $WindowsRoot = Join-Path $OSDisk 'Windows'
            $ProgramDataRoot = Join-Path $OSDisk 'ProgramData'
            Write-Log -Message "Using OSDisk for log sources and pending archive storage: $OSDisk"
        }
        elseif (Test-Path -LiteralPath 'C:\Windows' -PathType Container) {
            $SystemDriveRoot = 'C:'
            $WindowsRoot = 'C:\Windows'
            $ProgramDataRoot = 'C:\ProgramData'
        }
        else {
            Write-Log -Level 'WARN' -Message 'No persistent Windows volume was found. Pending logs on the WinPE RAM disk will not survive reboot.'
        }
    }
    [pscustomobject]@{
        WindowsRoot     = $WindowsRoot
        ProgramDataRoot = $ProgramDataRoot
        SystemDriveRoot = $SystemDriveRoot
        PendingRoot     = Join-Path $WindowsRoot 'Temp\PendingOSDLogs'
    }
}

function Get-ComputerNameForArchive {
    $Candidates = @()

    foreach ($Name in @('OSDComputerName', '_SMSTSMachineName')) {
        try {
            $Candidates += [string]$script:TaskSequenceEnvironment.Value($Name)
        }
        catch {
            Write-Verbose "Cannot read Task Sequence variable '$Name' for archive naming."
        }
    }

    $Candidates += $env:COMPUTERNAME

    foreach ($Candidate in $Candidates) {
        if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
            return ($Candidate -replace '[^A-Za-z0-9_.-]', '_')
        }
    }

    return 'UnknownComputer'
}

function Resolve-UncDestination {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Path -notmatch '^\\\\([A-Za-z0-9][A-Za-z0-9.-]*)\\([^\\/:*?"<>|\x00-\x1f]+)(\\[^/:*?"<>|\x00-\x1f]*)?$') {
        throw 'OSDLogFileShare must be a UNC path with a server and share, without wildcards or device-path syntax.'
    }

    $Server = $Matches[1]
    $Share = $Matches[2]
    $ShareRoot = '\\{0}\{1}' -f $Server, $Share
    $Destination = $Path.TrimEnd('\')
    foreach ($Segment in $Destination.Substring(2).Split('\')) {
        if ([string]::IsNullOrWhiteSpace($Segment) -or $Segment -in @('.', '..') -or $Segment -match '[. ]$') {
            throw 'OSDLogFileShare contains an invalid path component.'
        }
    }

    return [pscustomobject]@{
        Server      = $Server
        Share       = $Share
        ShareRoot   = $ShareRoot
        Destination = $Destination
    }
}

function Test-TcpPort {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds
    )

    $Client = $null
    $AsyncResult = $null

    try {
        $Client = New-Object System.Net.Sockets.TcpClient
        $AsyncResult = $Client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $AsyncResult.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))) {
            return $false
        }
        $Client.EndConnect($AsyncResult)
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $Client) {
            $Client.Close()
        }
        if ($null -ne $AsyncResult) {
            $AsyncResult.AsyncWaitHandle.Close()
        }
    }
}

function Add-LogSource {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]$List,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [bool]$Recurse = $true
    )

    $Path = $Path.Replace('%WINDIR%', $script:WindowsRoot).Replace('%ProgramData%', $script:ProgramDataRoot).Replace('%SystemDrive%', $script:SystemDriveRoot)
    [void]$List.Add([pscustomobject]@{
            Name    = $Name
            Path    = [Environment]::ExpandEnvironmentVariables($Path)
            Recurse = $Recurse
        })
}

function Copy-LogSource {
    param(
        [Parameter(Mandatory = $true)]
        $Source,

        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]$ManifestItems
    )

    $Destination = Join-Path -Path $DestinationRoot -ChildPath $Source.Name

    try {
        if ([string]::IsNullOrWhiteSpace($Source.Path)) {
            [void]$ManifestItems.Add([pscustomobject]@{
                    Name    = $Source.Name
                    Source  = $Source.Path
                    Status  = 'NotFound'
                    Message = 'Source path is empty.'
                })
            return
        }

        if (-not (Test-Path -LiteralPath $Source.Path)) {
            [void]$ManifestItems.Add([pscustomobject]@{
                    Name    = $Source.Name
                    Source  = $Source.Path
                    Status  = 'NotFound'
                    Message = ''
                })
            return
        }

        [void](New-Item -Path $Destination -ItemType Directory -Force)
        $Item = Get-Item -LiteralPath $Source.Path -Force

        if ($Item.PSIsContainer) {
            foreach ($Child in Get-ChildItem -LiteralPath $Source.Path -Force -ErrorAction Stop) {
                if ($Child.PSIsContainer -and $Destination.StartsWith($Child.FullName.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
                    Write-Log -Level 'WARN' -Message "Skipping the staging ancestor during collection: $($Child.FullName)"
                    continue
                }
                if ($Source.Recurse -or -not $Child.PSIsContainer) {
                    Copy-Item -LiteralPath $Child.FullName -Destination $Destination -Recurse:$Source.Recurse -Force -ErrorAction Stop
                }
            }
        }
        else {
            Copy-Item -LiteralPath $Source.Path -Destination $Destination -Force -ErrorAction Stop
        }

        [void]$ManifestItems.Add([pscustomobject]@{
                Name    = $Source.Name
                Source  = $Source.Path
                Status  = 'Collected'
                Message = ''
            })
    }
    catch {
        $SafeError = Get-SafeErrorMessage -ErrorRecord $_
        [void]$ManifestItems.Add([pscustomobject]@{
                Name    = $Source.Name
                Source  = $Source.Path
                Status  = 'Error'
                Message = $SafeError
            })
        Write-Log -Level 'WARN' -Message "Source collection failed: $($Source.Path); $SafeError"
    }
}

function Export-Manifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [bool]$Extended,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [object[]]$ManifestItems = @()
    )

    $Manifest = [ordered]@{
        Tool               = 'Copy-OSDLogToFileShare'
        Version            = $script:Version
        CreatedUtc         = (Get-Date).ToUniversalTime().ToString('o')
        ComputerName       = $ComputerName
        ExtendedCollection = $Extended
        Items              = @($ManifestItems)
    }

    $Manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-ArchiveCreation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,

        [Parameter(Mandatory = $true)]
        [string]$ArchivePath
    )

    if (Test-Path -LiteralPath $ArchivePath) {
        Remove-Item -LiteralPath $ArchivePath -Force
    }

    [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceFolder, $ArchivePath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
}

function Confirm-SmbConnectionSecurity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,

        [Parameter(Mandatory = $true)]
        [string]$Share,

        [Parameter(Mandatory = $true)]
        [string]$UserName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('SMB2', 'SMB3')]
        [string]$MinimumDialect,

        [Parameter(Mandatory = $true)]
        [bool]$AllowUnencrypted,

        [Parameter(Mandatory = $true)]
        [bool]$AllowUnverified
    )

    if ($null -eq (Get-Command -Name Get-SmbConnection -ErrorAction SilentlyContinue)) {
        if (-not $AllowUnverified) {
            throw 'SMB inspection is unavailable. An explicit AllowUnverifiedSmb decision is required.'
        }
        Write-Log -Level 'WARN' -Message 'Compatibility enabled: AllowUnverifiedSmb. SMB dialect, integrity, and privacy cannot be inspected.'
        return
    }

    try {
        $Connections = @(Get-SmbConnection -ServerName $Server -ErrorAction Stop | Where-Object {
                $_.ShareName -eq $Share -and $_.Credential -eq $UserName
            })
        if ($Connections.Count -ne 1) {
            throw 'No unambiguous SMB connection was found for the requested share and credential.'
        }
        $Connection = $Connections[0]
    }
    catch {
        $SafeError = Get-SafeErrorMessage -ErrorRecord $_
        if ($AllowUnverified) {
            Write-Log -Level 'WARN' -Message "Compatibility enabled: AllowUnverifiedSmb bypassed SMB connection inspection failure: $SafeError"
            return
        }

        throw "Unable to verify SMB connection security: $SafeError"
    }

    $Unknown = @()
    $Dialect = ''
    if ($null -ne $Connection.PSObject.Properties['Dialect']) {
        $Dialect = [string]$Connection.Dialect
    }
    if ([string]::IsNullOrWhiteSpace($Dialect)) {
        $Unknown += 'dialect'
    }
    else {
        $Pattern = if ($MinimumDialect -eq 'SMB3') {
            '^3\.\d+(\.\d+)?$'
        }
        else {
            '^[23]\.\d+(\.\d+)?$'
        }
        if ($Dialect -notmatch $Pattern) {
            throw "SMB dialect '$Dialect' does not meet the required minimum '$MinimumDialect'."
        }
    }

    $Signed = $null
    $Encrypted = $null
    if ($null -ne $Connection.PSObject.Properties['Signed'] -and $Connection.Signed -is [bool]) {
        $Signed = $Connection.Signed
    }
    if ($null -ne $Connection.PSObject.Properties['Encrypted'] -and $Connection.Encrypted -is [bool]) {
        $Encrypted = $Connection.Encrypted
    }
    if ($Encrypted -ne $true -and $Signed -ne $true) {
        if ($Signed -eq $false -and $Encrypted -eq $false) {
            throw 'SMB integrity is required but the connection is neither signed nor encrypted.'
        }
        $Unknown += 'integrity'
    }
    if (-not $AllowUnencrypted) {
        if ($Encrypted -eq $false) {
            throw 'SMB privacy is required but the connection is not encrypted.'
        }
        if ($null -eq $Encrypted) {
            $Unknown += 'privacy'
        }
    }
    if ($Unknown.Count) {
        if (-not $AllowUnverified) {
            throw "SMB properties cannot be verified: $($Unknown -join ', ')."
        }
        Write-Log -Level 'WARN' -Message "Compatibility enabled: AllowUnverifiedSmb. Unverified properties: $($Unknown -join ', ')."
    }

    Write-Log -Message "SMB inspection: Dialect=$Dialect; Signed=$Signed; Encrypted=$Encrypted"
}

function Get-SmbMappingOption {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemotePath,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential
    )
    $Command = Get-Command New-SmbMapping -ErrorAction SilentlyContinue
    if ($null -eq $Command -and -not $AllowUnverifiedSmb) {
        throw 'Per-connection SMB controls are unavailable. An explicit AllowUnverifiedSmb decision is required.'
    }
    $Options = @{ RemotePath = $RemotePath; Persistent = $false; ErrorAction = 'Stop' }
    if ($AllowNtlmV2) {
        $Policy = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name LmCompatibilityLevel -ErrorAction Stop
        if ($Policy.LmCompatibilityLevel -notin @(3, 4, 5)) {
            throw 'AllowNtlmV2 requires an existing LmCompatibilityLevel of 3 through 5. No policy was changed.'
        }
        Write-Log -Level 'WARN' -Message 'Compatibility enabled: AllowNtlmV2 with an existing NTLMv2-only client policy.'
    }
    elseif ($null -eq $Command -or -not $Command.Parameters.ContainsKey('BlockNTLM')) {
        throw 'Per-connection NTLM blocking is unavailable. An explicit AllowNtlmV2 decision with an existing NTLMv2-only client policy is required.'
    }
    if ($null -eq $Command) {
        Write-Log -Level 'WARN' -Message 'Compatibility enabled: AllowUnverifiedSmb uses a credentialed PSDrive without per-connection SMB controls.'
        return $null
    }
    if (-not $AllowNtlmV2) {
        $Options.BlockNTLM = $true
    }
    foreach ($Requirement in @('RequireIntegrity', 'RequirePrivacy')) {
        if ($Requirement -eq 'RequirePrivacy' -and $AllowUnencryptedSmb) {
            continue
        }
        if ($Command.Parameters.ContainsKey($Requirement)) {
            $Options[$Requirement] = $true
        }
        elseif (-not $AllowUnverifiedSmb) {
            throw "Per-connection $Requirement is unavailable. An explicit AllowUnverifiedSmb decision is required."
        }
        else {
            Write-Log -Level 'WARN' -Message "Compatibility enabled: AllowUnverifiedSmb cannot enforce $Requirement before connecting."
        }
    }
    if ($Command.Parameters.ContainsKey('Credential') -and -not $Options.ContainsKey('BlockNTLM')) {
        $Options.Credential = $Credential
    }
    else {
        # BlockNTLM and PSCredential belong to different inbox cmdlet parameter sets.
        $Options.UserName = $Credential.UserName
        $Options.Password = $Credential.GetNetworkCredential().Password
    }
    return $Options
}

function Send-Archive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationShare,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds
    )

    $PathInfo = Resolve-UncDestination -Path $DestinationShare
    $MappingOptions = Get-SmbMappingOption -RemotePath $PathInfo.ShareRoot -Credential $Credential
    if (-not $AllowUnverifiedSmb -and $null -eq (Get-Command Get-SmbConnection -ErrorAction SilentlyContinue)) {
        throw 'SMB inspection is unavailable. An explicit AllowUnverifiedSmb decision is required.'
    }
    if (-not (Test-TcpPort -ComputerName $PathInfo.Server -Port 445 -TimeoutSeconds $TimeoutSeconds)) {
        throw "TCP 445 is not reachable on $($PathInfo.Server)."
    }

    $DriveName = 'OSDLOG' + ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $Mapped = $false
    $DriveCreated = $false

    try {
        if ($null -ne $MappingOptions) {
            if (@(Get-SmbMapping -ErrorAction Stop | Where-Object RemotePath -EQ $PathInfo.ShareRoot).Count) {
                throw 'An SMB mapping already exists for the destination. It will not be reused or removed.'
            }
            [void](New-SmbMapping @MappingOptions)
            $Mapped = $true
        }
        else {
            [void](New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $PathInfo.ShareRoot -Credential $Credential -Scope Script -ErrorAction Stop)
            $DriveCreated = $true
        }
        Confirm-SmbConnectionSecurity -Server $PathInfo.Server -Share $PathInfo.Share -UserName $Credential.UserName -MinimumDialect $MinimumSmbDialect -AllowUnencrypted ([bool]$AllowUnencryptedSmb) -AllowUnverified ([bool]$AllowUnverifiedSmb)

        if (-not (Test-Path -LiteralPath $PathInfo.Destination -PathType Container)) {
            throw "Destination folder does not exist: $($PathInfo.Destination)"
        }

        $RemoteArchive = Join-Path -Path $PathInfo.Destination -ChildPath (Split-Path -Path $ArchivePath -Leaf)
        Copy-Item -LiteralPath $ArchivePath -Destination $RemoteArchive -Force -ErrorAction Stop

        $LocalLength = (Get-Item -LiteralPath $ArchivePath).Length
        $RemoteLength = (Get-Item -LiteralPath $RemoteArchive).Length
        if ($LocalLength -ne $RemoteLength) {
            throw "Remote archive size mismatch. Local=$LocalLength Remote=$RemoteLength"
        }

        return $RemoteArchive
    }
    finally {
        if ($null -ne $MappingOptions) {
            $MappingOptions.Clear()
        }
        if ($Mapped) {
            Remove-SmbMapping -RemotePath $PathInfo.ShareRoot -Force -ErrorAction Stop
        }
        if ($DriveCreated) {
            Remove-PSDrive -Name $DriveName -Force -ErrorAction Stop
        }
    }
}

$ExitCode = 1
$StagingRoot = $null
$ArchivePath = $null

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $script:TaskSequenceEnvironment = Get-TaskSequenceEnvironment
    Initialize-Log
    Write-Log -Message "Copy-OSDLogToFileShare started. Version=$script:Version"

    $DestinationShare = Get-TaskSequenceVariable -Environment $script:TaskSequenceEnvironment -Name 'OSDLogFileShare'
    $UserName = Get-TaskSequenceVariable -Environment $script:TaskSequenceEnvironment -Name 'OSDLogUserName'
    $Password = Get-TaskSequenceVariable -Environment $script:TaskSequenceEnvironment -Name 'OSDLogPassword'
    $SecurePassword = $null

    try {
        $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $script:Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
    }
    finally {
        $Password = $null
        $SecurePassword = $null
    }

    $ComputerName = Get-ComputerNameForArchive
    $Timestamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N')
    $Storage = Get-LogStorage
    $PendingRoot = $Storage.PendingRoot
    $script:WindowsRoot = $Storage.WindowsRoot
    $script:ProgramDataRoot = $Storage.ProgramDataRoot
    $script:SystemDriveRoot = $Storage.SystemDriveRoot

    if ($AllowUnverifiedSmb) {
        Write-Log -Level 'WARN' -Message 'Compatibility enabled: AllowUnverifiedSmb.'
    }
    if ($AllowUnencryptedSmb) {
        Write-Log -Level 'WARN' -Message 'Compatibility enabled: AllowUnencryptedSmb.'
    }
    if ($MinimumSmbDialect -eq 'SMB2') {
        Write-Log -Level 'WARN' -Message 'Compatibility enabled: MinimumSmbDialect=SMB2.'
    }
    if ($AllowNtlmV2) {
        Write-Log -Level 'WARN' -Message 'Compatibility requested: AllowNtlmV2. Existing NTLMv2-only client policy must be verified before connecting.'
    }

    [void](New-Item -Path $PendingRoot -ItemType Directory -Force)
    $StagingRoot = Join-Path -Path $PendingRoot -ChildPath "$ComputerName-$Timestamp"
    [void](New-Item -Path $StagingRoot -ItemType Directory -Force)

    $Sources = New-Object System.Collections.ArrayList

    try {
        $TaskSequenceLogPath = [string]$script:TaskSequenceEnvironment.Value('_SMSTSLogPath')
        Add-LogSource -List $Sources -Name 'TaskSequence' -Path $TaskSequenceLogPath
    }
    catch {
        Write-Log -Level 'WARN' -Message 'Cannot read _SMSTSLogPath for source collection; Task Sequence logs will not be included.'
    }

    Add-LogSource -List $Sources -Name 'CopyOSDLogs' -Path $script:LogPath -Recurse:$false
    Add-LogSource -List $Sources -Name 'CCMSetup' -Path '%WINDIR%\CCMSetup\Logs'
    Add-LogSource -List $Sources -Name 'CCMLogs' -Path '%WINDIR%\CCM\Logs'
    Add-LogSource -List $Sources -Name 'Panther' -Path '%WINDIR%\Panther'
    Add-LogSource -List $Sources -Name 'NetSetup' -Path '%WINDIR%\Debug\NetSetup.log' -Recurse:$false
    Add-LogSource -List $Sources -Name 'SetupApiDevice' -Path '%WINDIR%\Inf\setupapi.dev.log' -Recurse:$false
    Add-LogSource -List $Sources -Name 'SetupApiApplication' -Path '%WINDIR%\Inf\setupapi.app.log' -Recurse:$false
    Add-LogSource -List $Sources -Name 'IntuneManagementExtension' -Path '%ProgramData%\Microsoft\IntuneManagementExtension\Logs'
    Add-LogSource -List $Sources -Name 'PatchMyPCInstallLogs' -Path '%ProgramData%\PatchMyPCInstallLogs'
    Add-LogSource -List $Sources -Name 'PatchMyPCLogs' -Path '%ProgramData%\PatchMyPC\Logs'
    Add-LogSource -List $Sources -Name 'ApplyDriverPackageFallback' -Path '%WINDIR%\Temp\ApplyDriverPackage.log' -Recurse:$false

    if ($IncludeExtendedLogs) {
        Add-LogSource -List $Sources -Name 'UnattendGC' -Path '%WINDIR%\Panther\UnattendGC'
        Add-LogSource -List $Sources -Name 'DISM' -Path '%WINDIR%\Logs\DISM'
        Add-LogSource -List $Sources -Name 'CBS' -Path '%WINDIR%\Logs\CBS'
        Add-LogSource -List $Sources -Name 'MoSetup' -Path '%WINDIR%\Logs\MoSetup'
        Add-LogSource -List $Sources -Name 'SetupDiag' -Path '%WINDIR%\Logs\SetupDiag'
        Add-LogSource -List $Sources -Name 'WindowsUpdate' -Path '%WINDIR%\Logs\WindowsUpdate'
        Add-LogSource -List $Sources -Name 'USOShared' -Path '%ProgramData%\USOShared\Logs'
        Add-LogSource -List $Sources -Name 'UpgradePanther' -Path '%SystemDrive%\$WINDOWS.~BT\Sources\Panther'
        Add-LogSource -List $Sources -Name 'UpgradeUnattendGC' -Path '%SystemDrive%\$WINDOWS.~BT\Sources\Panther\UnattendGC'
        Add-LogSource -List $Sources -Name 'UpgradeRollback' -Path '%SystemDrive%\$WINDOWS.~BT\Sources\Rollback'
    }

    $ContentRoot = Join-Path -Path $StagingRoot -ChildPath 'Content'
    [void](New-Item -Path $ContentRoot -ItemType Directory -Force)

    $ManifestItems = New-Object System.Collections.ArrayList
    foreach ($Source in $Sources) {
        Copy-LogSource -Source $Source -DestinationRoot $ContentRoot -ManifestItems $ManifestItems
    }

    $MetaRoot = Join-Path -Path $StagingRoot -ChildPath '_Meta'
    [void](New-Item -Path $MetaRoot -ItemType Directory -Force)

    Export-Manifest -Path (Join-Path -Path $MetaRoot -ChildPath 'Manifest.json') -ComputerName $ComputerName -Extended ([bool]$IncludeExtendedLogs) -ManifestItems @($ManifestItems)
    Copy-Item -LiteralPath $script:LogPath -Destination (Join-Path -Path $MetaRoot -ChildPath 'CopyOSDLogs.log') -Force -ErrorAction Stop

    $ArchivePath = Join-Path -Path $PendingRoot -ChildPath "$ComputerName-$Timestamp.zip"
    Invoke-ArchiveCreation -SourceFolder $StagingRoot -ArchivePath $ArchivePath

    $ArchiveLength = (Get-Item -LiteralPath $ArchivePath).Length
    Write-Log -Message "Archive created: $ArchivePath; Bytes=$ArchiveLength"

    $Uploaded = $false
    for ($Attempt = 1; $Attempt -le $RetryCount; $Attempt++) {
        try {
            Write-Log -Message "Upload attempt $Attempt of $RetryCount."
            $RemoteArchive = Send-Archive -ArchivePath $ArchivePath -DestinationShare $DestinationShare -Credential $script:Credential -TimeoutSeconds $TimeoutSeconds
            Write-Log -Message "Upload verified: $RemoteArchive"
            $Uploaded = $true
            break
        }
        catch {
            Write-Log -Level 'WARN' -Message "Upload attempt $Attempt failed: $(Get-SafeErrorMessage -ErrorRecord $_)"
            if (($Attempt -lt $RetryCount) -and ($RetryDelaySeconds -gt 0)) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }

    if (-not $Uploaded) {
        throw "Upload failed after $RetryCount attempt(s). Pending local archive retained: $ArchivePath"
    }

    Remove-Item -LiteralPath $StagingRoot -Recurse -Force -ErrorAction Stop
    Remove-Item -LiteralPath $ArchivePath -Force -ErrorAction Stop
    $ExitCode = 0
}
catch {
    Write-Log -Level 'ERROR' -Message (Get-SafeErrorMessage -ErrorRecord $_)
    $ExitCode = 1
}
finally {
    Write-Log -Message "Script exit code: $ExitCode"
    $script:Credential = $null
}

if ($ExitCode -eq 0) {
    Write-Output 'OSD log archive uploaded and verified successfully.'
}
else {
    Write-Output 'OSD log collection or upload failed. See CopyOSDLogs.log.'
}

exit $ExitCode
