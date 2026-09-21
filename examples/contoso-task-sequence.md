---
title: Contoso task sequence example
---

# Contoso task sequence example

[Documentation home](../index.md) | [Development](../docs/development.md) | [Deployment](../docs/deployment.md) | [Compatibility](../docs/compatibility.md) | [Validation](../docs/validation.md)

```text
Set variables
Run Copy-OSDLogToFileShare.ps1
Save %_SMSTSLastActionRetCode% as OSDLogCopyExitCode
Clear variables (also on script failure)
Report/propagate saved script result
```

```text
OSDLogFileShare = \\fileserver.contoso.com\OSDLogs$\Logs
OSDLogUserName  = CONTOSO\svc-configmgr-copylogs
OSDLogPassword  = <hidden password>
```

For the Task Sequence step's **Parameters** field (not standalone commands):

```text
# Standard profile: leave parameters empty
# Extended profile:
-IncludeExtendedLogs
```

Use the extracted `Scripts` folder as the package source and set **Script name**
to `Copy-OSDLogToFileShare.ps1`. Disable parameter logging and set an external timeout.
Keep passwords hidden and clear all three custom variables using native Task Sequence steps with empty values even if upload fails.
Capture the return code immediately after the script, before cleanup changes the last-action status. Output text is not an exit code; **Continue on error** must not suppress the saved failure.
See the [credential lifecycle](../docs/deployment.md#credential-lifecycle) for failure handling and [compatibility](../docs/compatibility.md) before approving exceptions.
