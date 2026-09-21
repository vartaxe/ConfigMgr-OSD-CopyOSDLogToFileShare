---
title: Logging
---

# Logging

[Documentation home](../index.md) | [Development](development.md) | [Deployment](deployment.md) | [Compatibility](compatibility.md) | [Validation](validation.md)

## Output locations

| Output | Location |
|---|---|
| Live CMTrace log | `_SMSTSLogPath\CopyOSDLogs.log` when the folder exists; otherwise `%WINDIR%\Temp\CopyOSDLogs.log` in the running environment |
| Local staging | `Windows\Temp\PendingOSDLogs\<Computer>-<Timestamp>-<GUID>\` on the selected Windows volume |
| Local ZIP | The same pending root, named `<Computer>-<Timestamp>-<GUID>.zip` |
| Remote ZIP | The existing folder in `OSDLogFileShare`, using the same ZIP filename |

In WinPE, `OSDisk` selects the offline target when valid. A fallback to the WinPE RAM disk is volatile; retrieve retained work before rebooting. See [volume selection](architecture.md#volume-and-name-selection).

## Archive contents

- `Content\<SourceName>\...`: copied diagnostics from the [selected profile](architecture.md#collection-profiles).
- `_Meta\Manifest.json`: tool/version, UTC creation time, computer name, extended-profile selection, and source results.
- `_Meta\CopyOSDLogs.log`: a snapshot taken **before ZIP creation and upload**. Later retries, verification, and the final exit code are in the live log, not that snapshot.

Each manifest item has `Name`, `Source`, `Status`, and `Message`. Status is `Collected`, `NotFound`, or `Error`. `Collected` means the source-copy operation completed; it does not certify that an actively changing source was captured consistently. Other sources continue after a missing or failed optional source.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Archive uploaded, remote byte size matched, connection cleanup completed, and this run's local staging and ZIP were removed |
| `1` | Initialization, required input, archive creation, upload/verification, or cleanup failed |

Missing or unreadable optional sources are reported in the manifest and warnings, but do not alone force exit `1`. Size equality is not a content hash or proof that every desired log was collected.
PowerShell startup/parameter errors or external termination can produce host-specific failures before the script completes. Treat any nonzero step result as failure and preserve it through [credential cleanup](deployment.md#credential-lifecycle).

## Retention and failure behavior

- After verified upload, cleanup deletes **only this run's** staging directory and ZIP, in that order.
- Upload failure retains the local ZIP and staging. Archive-creation failure retains staging and may leave an incomplete ZIP; do not assume that ZIP is usable.
- Local cleanup failure returns `1`, even if the remote copy succeeded. Some staging files may already have been removed; the local ZIP is not removed before staging cleanup finishes.
- Existing local ZIP names are never replaced by archive creation. Previous pending runs are not retried, pruned, or deleted by a later run.
- A failed remote copy can leave a partial file. Retries overwrite the same current-run remote filename; the script does not delete remote partials or old archives.
- The dedicated log is append-only; the script does not rotate or delete it.

Apply an explicit local and server retention policy outside this utility. Budget for both staging and compressed data, and verify retained evidence before manually removing it.

## Sensitive data

Script-generated failure messages use known safe categories or exception types rather than raw exception text. Explicit supplied credentials are redacted from dedicated log messages. Failure sanitization also applies to manifest error messages; it does **not** scrub source paths, computer names, copied files, or third-party logs.

Treat all logs and archives as internal diagnostic data. Hide password variables, disable parameter logging, and check both the dedicated log and `smsts.log` during your pilot. Share only sanitized excerpts, never raw archives in public issues.
