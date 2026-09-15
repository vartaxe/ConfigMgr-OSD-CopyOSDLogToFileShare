# Troubleshooting

## Validation

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1
```

## Common checks

- Confirm the package is distributed to distribution points.
- Confirm the Task Sequence step references the packaged script, not an older inline version.
- Confirm variables are set and hidden where appropriate.
- Review the dedicated script log in `_SMSTSLogPath` or `%WINDIR%\Temp`.
- Sanitize logs before sharing externally.
- If WinPE or an older client refuses SMB upload, review [compatibility prerequisites](compatibility.md); missing inspection does not silently disable verification.
- On upload failure, retrieve the retained archive before rebooting WinPE. A RAM-disk fallback does not survive reboot.
- `TimeoutSeconds` controls only TCP preflight. Check the external Task Sequence timeout for stalled authentication or transfers.
- A checksum mismatch requires reviewing the changed bytes and regenerating the manifest, not bypassing final validation with `-SkipChecksums`.

## Live validation pending

The following scenarios require live testing and are not represented as completed by the repository checks:

- Current WinPE boot image and a full Windows Task Sequence
- SMB3 encrypted destination and SMB2 compatibility destination
- Wrong credentials, access denied, and unavailable destination
- Interrupted upload and local archive retention after failure
- Sanitized dedicated log and `smsts.log`
