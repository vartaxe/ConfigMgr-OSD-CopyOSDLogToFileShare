---
title: Architecture
---

# Architecture

[Documentation home](../index.md) | [Development](development.md) | [Deployment](deployment.md) | [Compatibility](compatibility.md) | [Validation](validation.md)

<p align="center">
    <picture>
        <source media="(max-width: 960px)" srcset="../assets/copylog-flow-compact.svg" width="440">
        <img src="../assets/copylog-flow.svg" alt="Set log variables, collect standard logs, write Manifest.json, create a local ZIP, check TCP 445, upload and verify remote size, then clear credentials with native Task Sequence steps" width="1400">
    </picture>
</p>

[View the full-size collection workflow](../assets/copylog-flow.svg).

## Execution flow

1. Load .NET ZIP support and connect to `Microsoft.SMS.TSEnvironment`. The script is intended for Local System inside an active task sequence; it does not impersonate the upload account for local collection.
2. Initialize `CopyOSDLogs.log`, read the three required custom variables, and construct an in-process `PSCredential`. Native task sequence steps own the variables' creation and deletion.
3. Select the Windows volume and create a unique staging directory under `Windows\Temp\PendingOSDLogs`.
4. Copy each source into `Content\<SourceName>`. A missing or unreadable optional source is recorded in the manifest, and collection continues.
5. Write `_Meta\Manifest.json` and a snapshot of the dedicated log. Create the ZIP with .NET Framework `ZipFile.CreateFromDirectory`; an existing archive name is rejected without deleting its contents.
6. For each upload attempt, validate the UNC path and available SMB controls, then test TCP 445. Create a nonpersistent mapping, or use the explicitly approved PSDrive fallback. Inspect the connection before copying.
7. Copy to the existing destination folder and compare remote and local byte sizes. Clear mapping arguments and remove only the connection created by this attempt in `finally`. A cleanup failure is not reported as successful delivery.
8. After verified delivery, remove this run's staging directory and local ZIP. Return `0` only after those removals finish; otherwise return `1`. Native task sequence steps then clear credentials and propagate the saved result.

Retries cover the same newly created archive, not earlier pending runs. A retry can overwrite this run's partially uploaded remote file. Remote partial files are not automatically deleted. See [outputs and retention](logging.md#retention-and-failure-behavior).

## Volume and name selection

In full Windows, source roots come from `%WINDIR%`, `%ProgramData%`, and `%SystemDrive%`.
In WinPE, a valid `OSDisk` drive takes precedence, even before its `Windows` directory exists. Otherwise the script uses `C:\Windows` if present, then the current environment roots. The final fallback can be the volatile WinPE RAM disk.

Archive naming prefers `OSDComputerName`, then `_SMSTSMachineName`, then the environment computer name. Characters outside letters, digits, `_`, `.`, and `-` are replaced with `_`. A local timestamp and GUID distinguish runs.
The dedicated log still follows `_SMSTSLogPath` or the running environment's `%WINDIR%\Temp`; its location need not be on the selected offline volume.

## Collection profiles

Directories are copied recursively unless the entry names a single file. Paths below use the selected Windows volume, except `_SMSTSLogPath` and the dedicated log.

| Standard source | Path |
|---|---|
| Task sequence | `_SMSTSLogPath` |
| Dedicated script log | Current `CopyOSDLogs.log` |
| Client setup and client logs | `%WINDIR%\CCMSetup\Logs`, `%WINDIR%\CCM\Logs` |
| Windows setup | `%WINDIR%\Panther` |
| Domain join | `%WINDIR%\Debug\NetSetup.log` |
| Device and application setup | `%WINDIR%\Inf\setupapi.dev.log`, `%WINDIR%\Inf\setupapi.app.log` |
| Intune Management Extension | `%ProgramData%\Microsoft\IntuneManagementExtension\Logs` |
| Patch My PC | `%ProgramData%\PatchMyPCInstallLogs`, `%ProgramData%\PatchMyPC\Logs` |
| Driver-package fallback | `%WINDIR%\Temp\ApplyDriverPackage.log` |

`-IncludeExtendedLogs` adds these named sources:

| Extended source | Path |
|---|---|
| Unattended setup | `%WINDIR%\Panther\UnattendGC` |
| Servicing and setup diagnostics | `%WINDIR%\Logs\DISM`, `CBS`, `MoSetup`, `SetupDiag`, `WindowsUpdate` |
| Update Session Orchestrator | `%ProgramData%\USOShared\Logs` |
| Upgrade setup and rollback | `%SystemDrive%\$WINDOWS.~BT\Sources\Panther`, `Panther\UnattendGC`, `Rollback` |

`UnattendGC` can already be present beneath a recursively collected Panther directory; the extended profile also records it separately.
If a source contains staging, the direct child containing staging is skipped with a warning to prevent recursive self-collection. This is a file-copy snapshot, not a volume shadow copy; actively changing or locked files may be incomplete or reported as errors.

## API references

- [Task sequence environment COM object](https://learn.microsoft.com/en-us/intune/configmgr/develop/osd/how-to-use-task-sequence-variables-in-a-running-task-sequence)
- [Task sequence variables](https://learn.microsoft.com/en-us/intune/configmgr/osd/understand/task-sequence-variables)
- [.NET Framework ZIP creation and failure behavior](https://learn.microsoft.com/en-us/dotnet/api/system.io.compression.zipfile.createfromdirectory?view=netframework-4.8.1)
- [SMB connection controls and boundaries](compatibility.md)
