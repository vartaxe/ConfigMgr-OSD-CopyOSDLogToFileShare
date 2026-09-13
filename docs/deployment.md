# Deployment

## Recommended Task Sequence layout

<p align="center"><img src="../assets/task-sequence-flow.svg" alt="ConfigMgr Task Sequence pattern: set variables, run packaged script, validate result, clear variables on success and failure" width="100%"></p>

```text
Set variables
Run Copy-OSDLogToFileShare.ps1
Clear variables (also on failure)
Report/propagate the script result
```

## Run PowerShell Script step

```text
Package: package containing Scripts\Copy-OSDLogToFileShare.ps1
Script name: Scripts\Copy-OSDLogToFileShare.ps1
Execution policy: Bypass or AllSigned
Run as another account: Disabled
PowerShell parameter logging: Disabled
Time-out: environment-approved limit (for example, 20 minutes)
Success code: 0
```

## Variables

```text
OSDLogFileShare = \\fileserver.contoso.com\OSDLogs$\Logs
OSDLogUserName  = CONTOSO\svc-configmgr-copylogs
OSDLogPassword  = <hidden password>
```

## Parameters

The following are values for the Task Sequence step's **Parameters** field, not standalone PowerShell commands:

```text
# Standard profile: leave parameters empty
# Extended profile:
-IncludeExtendedLogs

# Explicit compatibility only:
-MinimumSmbDialect SMB2 -AllowUnencryptedSmb -AllowUnverifiedSmb -AllowNtlmV2
```

## Credential lifecycle

Create credential variables immediately before the script step and clear them immediately afterward using native Task Sequence steps.
Configure failure handling so cleanup executes when the script returns nonzero (for example, continue on error for the script step, capture its result, clear variables, then report the saved failure). Do not silently turn a failed upload into Task Sequence success.

The default requires SMB3, integrity and encryption, and fails closed if verification is unavailable.
Compatibility exceptions are not a recommended preset: approve only the specific exceptions needed. See [compatibility](compatibility.md) for per-connection controls, older-client policy prerequisites, and WinPE fallback requirements.

## Timing and prerequisites

`-RetryCount` is the total upload attempt count (1-10, default 3).
`-RetryDelaySeconds` is the delay between failed attempts (0-3600, default 300).
`-TimeoutSeconds` bounds only TCP 445 preflight (5-300, default 30), **not SMB authentication or file transfer**.
Use the Task Sequence's external timeout to bound the whole operation. An externally terminated process cannot guarantee its own cleanup.

Use an active ConfigMgr Task Sequence running as Local System, Windows PowerShell 5.1, and WinPE PowerShell/.NET components where applicable.
For offline WinPE collection, set `OSDisk` to the target Windows drive, with or without a trailing backslash.
Ensure the account has the required share and NTFS permissions without granting broad access.
Do not pass a password on the command line. Disable parameter logging, hide the password variable, and verify sanitized `smsts.log` during live testing.
