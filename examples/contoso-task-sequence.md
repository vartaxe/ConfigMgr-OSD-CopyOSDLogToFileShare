# Contoso Task Sequence example

```text
Set variables
Run Copy-OSDLogToFileShare.ps1
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

Use `Scripts\Copy-OSDLogToFileShare.ps1` from the distributed package, disable parameter logging, and set an external timeout.
Keep passwords hidden and clear all three custom variables using native Task Sequence steps even if upload fails.
See [deployment](../docs/deployment.md) for failure handling and [compatibility](../docs/compatibility.md) before approving exceptions.
