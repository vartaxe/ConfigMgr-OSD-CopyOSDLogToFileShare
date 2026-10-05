---
title: Deployment
---

# Deployment

[Documentation home](../index.md) | [Development](development.md) | [Deployment](deployment.md) | [Compatibility](compatibility.md) | [Validation](validation.md)

## Requirements

Use an active ConfigMgr Task Sequence running as Local System with Windows PowerShell 5.1 and .NET Framework ZIP support. There are no third-party runtime modules. PowerShell 7 is not a supported deployment runtime.

For WinPE, include `WinPE-WMI`, `WinPE-NetFX`, `WinPE-Scripting`, and `WinPE-PowerShell` with matching boot-image architecture and ADK versions. These components do not guarantee that SMB inspection or newer per-connection controls are available; review [compatibility](compatibility.md) for the actual image.

Create the destination folder in advance. Grant a dedicated account the required share and NTFS rights to traverse the destination, create/write files, and read file metadata for verification; do not grant administrative access merely to upload logs.
Provide DNS and TCP 445 connectivity, sufficient local space for both staging and the ZIP, and an approved external timeout.

## Recommended task sequence layout

<p align="center">
    <picture>
        <source media="(max-width: 960px)" srcset="../assets/task-sequence-flow-compact.svg" width="440">
        <img src="../assets/task-sequence-flow.svg" alt="Set variables, run the packaged script and capture its result, clear credentials on success and failure, then report the saved result" width="1400">
    </picture>
</p>

[View the full-size Task Sequence diagram](../assets/task-sequence-flow.svg). The equivalent sequence is:

```text
Set variables
Run Copy-OSDLogToFileShare.ps1 and capture its result
Clear variables (also on failure)
Report/propagate the script result
```

## Run PowerShell Script step

Use the extracted release's **`Scripts` folder as the ConfigMgr package source**.
Distribute that package and configure:

```text
Package source: <extracted release>\Scripts
Script name: Copy-OSDLogToFileShare.ps1
Execution policy: your organization's approved policy
Run as another account: Disabled
PowerShell parameter logging: Disabled
Time-out: environment-approved limit (for example, 20 minutes)
Success code: 0
```

The script-name field is relative to the package source. With the recommended
source folder, use only the filename. If an existing package instead uses the
release root as its source, it still needs `Scripts\Copy-OSDLogToFileShare.ps1`;
changing the label alone would break that package. Do not paste a shell command
or `.\` prefix into the script-name field.

Download and verify the versioned package before distributing it. The repository script is not Authenticode-signed. If your policy requires **AllSigned**, sign an approved deployment copy and keep it in the package rather than pasting it into an inline step. Signing changes the file's bytes, so separately track and validate that deployment copy.

## Variables

| Variable | Purpose |
|---|---|
| `OSDLogFileShare` | Required existing UNC folder, for example `\\fileserver.contoso.com\OSDLogs$\Logs` |
| `OSDLogUserName` | Required dedicated upload account, for example `CONTOSO\svc-configmgr-copylogs` |
| `OSDLogPassword` | Required hidden password, created immediately before the step |
| `OSDisk` | Optional target drive for offline WinPE collection, such as `C:` or `C:\` |
| `OSDComputerName` | Optional preferred archive-name prefix |

The script also reads `_SMSTSLogPath`, `_SMSTSInWinPE`, and `_SMSTSMachineName`. It does not read Network Access Account or reserved task sequence credentials.
UNC paths may contain spaces and nested folders, but not wildcards, device paths, empty internal components, `.`/`..`, or components ending in a dot or space.

## Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `RetryCount` | `3` | Total upload attempts, `1`–`10` |
| `RetryDelaySeconds` | `300` | Delay between failed attempts, `0`–`3600` seconds |
| `TimeoutSeconds` | `30` | TCP 445 preflight timeout, `5`–`300` seconds |
| `IncludeExtendedLogs` | Off | Add the [extended source profile](architecture.md#collection-profiles) |
| `MinimumSmbDialect` | `SMB3` | Minimum inspected dialect; `SMB2` is an explicit exception |
| `AllowUnencryptedSmb` | Off | Permit unencrypted SMB while retaining integrity requirements |
| `AllowUnverifiedSmb` | Off | Permit unavailable inspection or per-connection controls |
| `AllowNtlmV2` | Off | Permit NTLM only with an existing client policy value of `3`–`5` |

These are values for the step's **Parameters** field, not standalone commands or PowerShell host arguments:

```text
# Standard profile: leave parameters empty
# Extended profile:
-IncludeExtendedLogs
```

Compatibility switches are independent decisions, not a recommended preset. Approve only the [specific exceptions](compatibility.md#compatibility-controls) your environment requires.

## Credential lifecycle

1. Set the three custom variables immediately before the script. Mark `OSDLogPassword` as hidden and keep `OSDLogPowerShellParameters` disabled.
2. Allow the script step to continue on error **only so cleanup can run**. Keep its success-code list limited to `0`.
3. Immediately save `%_SMSTSLastActionRetCode%` to a custom variable such as `OSDLogCopyExitCode` using **Set Task Sequence Variable**, before any cleanup step replaces the last-action status.
4. Clear `OSDLogPassword`, `OSDLogUserName`, and `OSDLogFileShare` with native variable-setting steps using empty values. An empty value deletes a custom variable from the task sequence environment.
5. After cleanup, use the saved result to enter your failure-reporting path when it is nonzero. Do not interpret **Continue on error** or a successful cleanup step as a successful upload.

The step's **Output to task sequence variable** setting captures text, not the process exit code. Use `_SMSTSLastActionRetCode` for the result, and ensure the script actually ran: a skipped step does not produce a new script result.
This script clears its in-process credential reference but does not remove task sequence variables. No in-process cleanup can guarantee execution after external termination.

## Timeouts and rollout

`TimeoutSeconds` bounds only TCP preflight, **not** SMB authentication, file copying, compression, or connection cleanup. Allow for `(RetryCount - 1) × RetryDelaySeconds` plus collection and transfer time when setting the task sequence timeout.
The default retry delays alone can consume ten minutes. ConfigMgr can terminate the PowerShell process when the external timeout expires.

Pilot the exact package, boot image, account, and share before broad rollout. Inspect [outputs and exit codes](logging.md), verify credential cleanup and sanitized logs, and complete the [live checklist](validation.md#required-live-tests).

## Microsoft references

- [Run PowerShell Script step](https://learn.microsoft.com/en-us/intune/configmgr/osd/understand/task-sequence-steps#BKMK_RunPowerShellScript)
- [Setting, accessing, hiding, and deleting task sequence variables](https://learn.microsoft.com/en-us/intune/configmgr/osd/understand/using-task-sequence-variables)
- [Last-action return code](https://learn.microsoft.com/en-us/intune/configmgr/osd/understand/task-sequence-variables#SMSTSLastActionRetCode)
- [WinPE optional components and dependencies](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-add-packages--optional-components-reference?view=windows-11)
