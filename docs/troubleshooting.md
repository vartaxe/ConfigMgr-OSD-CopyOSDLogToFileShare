---
title: Troubleshooting
---

# Troubleshooting

[Documentation home](../index.md) | [Development](development.md) | [Deployment](deployment.md) | [Compatibility](compatibility.md) | [Validation](validation.md)

## Start with the recorded result

Confirm that distribution points have the intended package and that the step references its script, not an older inline copy. Record the script version and saved step exit code, then inspect the live `CopyOSDLogs.log` in `_SMSTSLogPath` or `%WINDIR%\Temp`.
The log inside the ZIP predates upload and cannot explain later authentication or transfer failures.

| Symptom or safe error category | Next check |
|---|---|
| `Microsoft.SMS.TSEnvironment is unavailable` | Run only inside an active task sequence with the intended Local System context |
| Required variable is empty | Set `OSDLogFileShare`, `OSDLogUserName`, and hidden `OSDLogPassword` immediately before the step |
| UNC path is invalid | Use an existing `\\server\share\folder`; remove device-path syntax, wildcards, empty components, and `.`/`..` |
| Per-connection controls or NTLM blocking are unavailable | Check the deployed image's cmdlet parameters and [approved compatibility settings](compatibility.md#compatibility-controls); do not enable every switch as a workaround |
| `AllowNtlmV2` policy requirement fails | Confirm an explicit existing `LmCompatibilityLevel` of `3`, `4`, or `5`; the script does not create or infer the setting |
| TCP 445 is not reachable | Check DNS, routing, firewall rules, and the server; retries do not repair those prerequisites |
| `Unable to verify SMB connection security` | Check SMB inspection permissions and the exact server/share/credential identity; ambiguous or missing results fail closed |
| An SMB mapping already exists | Identify its owner and use an approved execution arrangement; the script will not remove someone else's mapping |
| Destination folder does not exist | Pre-create the full UNC folder and verify the account can traverse it |
| Access or transfer failure / size verification failed | Check share and NTFS rights, free space, connectivity, and server diagnostics; retain the local ZIP while investigating |
| `Manifest.json` contains `Error` or `NotFound` | Review that source path, deployment phase, file locks, and permissions; other sources may still have uploaded |
| Generic `IOException` during archiving | Check local space, path length, locks, and an existing archive filename; inspect staging and do not assume a partial ZIP is valid |
| Remote file exists but exit code is `1` | Connection cleanup or local cleanup may have failed after copying; check the live log before treating delivery as successful |
| Process stalls or is terminated | `TimeoutSeconds` covers only TCP preflight; review the external step timeout and preserved task sequence result |

## Recover retained evidence

Look under `Windows\Temp\PendingOSDLogs` on the [selected Windows volume](architecture.md#volume-and-name-selection). If WinPE fell back to RAM-disk storage, retrieve it before rebooting.
Upload failure retains staging and the ZIP; archive creation can leave an incomplete ZIP. Validate readability before using it as evidence.

The script does not automatically resend earlier archives or remove partial remote files. Follow an approved manual recovery and retention procedure, using the [documented cleanup behavior](logging.md#retention-and-failure-behavior).
Clear custom credentials on both success and failure, and preserve the failed step result rather than hiding it behind successful cleanup.

## Validate source changes

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1 -Tag v1.0.0
```

A checksum mismatch means the source bytes differ. Review intended changes, normalize them, and regenerate the manifest using the [documented recipe](release-process.md#checksum-checkout-convention); do not bypass final checks.
Automated checks do not replace the [environment rollout checklist](validation.md#required-live-tests). Share only sanitized diagnostics through [support](../SUPPORT.md), or use [private security reporting](../SECURITY.md#reporting) for sensitive findings.
