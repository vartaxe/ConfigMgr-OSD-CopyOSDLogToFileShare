<p align="center">
  <picture>
    <source media="(max-width: 720px)" srcset="assets/banner-compact.svg?v=1.0.0" width="640">
    <img src="assets/banner.svg?v=1.0.0" alt="Copy OSD Logs to File Share for ConfigMgr OSD; Copy-OSDLogToFileShare.ps1; Windows PowerShell 5.1." width="1280">
  </picture>
</p>

# ConfigMgr OSD Copy Logs to File Share

Collect deployment diagnostics into a named ZIP, upload it to an authenticated SMB share, and retain the local copy if delivery fails. The archive includes a source manifest; the dedicated CMTrace log records collection and upload results.

**Current version: 1.0.0.** This README follows `main`; downloads are versioned snapshots.

[Documentation](https://vartaxe.github.io/ConfigMgr-OSD-CopyOSDLogToFileShare/) | [Quick start](#quick-start) | [Deployment](docs/deployment.md) | [Compatibility](docs/compatibility.md) | [Security](SECURITY.md) | [Troubleshooting](docs/troubleshooting.md)

[![Release v1.0.0](https://img.shields.io/badge/RELEASE-v1.0.0-155799)](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/releases/tag/v1.0.0)
[![CI - main push](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/actions/workflows/ci.yml?query=branch%3Amain+event%3Apush)
![Windows PowerShell 5.1](https://img.shields.io/badge/Windows%20PowerShell-5.1-155799)
[![MIT license](https://img.shields.io/badge/license-MIT-117865)](LICENSE)

Standalone script: [public gist snapshot](https://gist.github.com/vartaxe/cd41f830cddc7853f5189713421a601b).
Keep its license and checksum files with the script; see [distribution](docs/distribution.md).

## Requirements

- An active ConfigMgr Task Sequence running as Local System with **Windows PowerShell 5.1**. PowerShell 7 is not a supported runtime.
- WinPE PowerShell/.NET components when collecting in WinPE, plus writable local storage for staging and the ZIP.
- An existing UNC destination, DNS/TCP 445 connectivity, and a dedicated account with the required share and NTFS permissions.
- SMB3, integrity, encryption, and per-connection NTLM blocking by default. Older clients and some WinPE images need explicitly approved [compatibility settings](docs/compatibility.md#compatibility-controls); there is no automatic security downgrade.

## Quick start

1. Download and verify the [release ZIP and SHA-256 sidecar](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/releases/tag/v1.0.0). Use its extracted **`Scripts` folder as the ConfigMgr package source**, then distribute the package. It contains the self-contained [`Copy-OSDLogToFileShare.ps1`](Scripts/Copy-OSDLogToFileShare.ps1).
2. Immediately before the script step, set `OSDLogFileShare` to your UNC folder, `OSDLogUserName` to the dedicated account, and `OSDLogPassword` to its **hidden** password.
3. In **Run PowerShell Script**, set **Script name** to `Copy-OSDLogToFileShare.ps1`. Leave **Run as another account** disabled and the **Parameters** field empty for the standard profile.
4. Set an external step timeout. Save the script result, clear credential variables on success **and failure**, then propagate the saved failure. Follow the [credential lifecycle](docs/deployment.md#credential-lifecycle) rather than treating **Continue on error** as success.

Add `-IncludeExtendedLogs` only when setup, servicing, update, or rollback diagnostics are needed. Do not pass credentials as script parameters or enable parameter logging.

## Outputs and results

| Output | Location or meaning |
|---|---|
| ZIP | `<Computer>-<Timestamp>-<GUID>.zip` in the configured UNC folder |
| Manifest | `_Meta/Manifest.json` inside the ZIP; lists collected, missing, and failed sources |
| Operational log | `CopyOSDLogs.log` in `_SMSTSLogPath`, falling back to `%WINDIR%\Temp` |
| Retained work | `Windows\Temp\PendingOSDLogs` on the selected Windows volume after upload failure |
| Exit `0` / `1` | Verified remote byte size and completed local cleanup / a collection, archive, upload, or cleanup failure |

Remote verification compares **byte size**, not a content hash. Optional source failures remain visible in the manifest and do not alone fail delivery. Previous retained runs are never automatically retried or pruned. See [log paths, archive contents, and exit codes](docs/logging.md) before setting retention policy.

## Documentation

- [Architecture](docs/architecture.md)
- [Compatibility](docs/compatibility.md)
- [Deployment](docs/deployment.md)
- [Development](docs/development.md)
- [Distribution](docs/distribution.md)
- [Examples](examples/README.md)
- [Logging](docs/logging.md)
- [Release process](docs/release-process.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Validation](docs/validation.md)

## Validation and rollout

The v1.0.0 automated checks cover Windows PowerShell 5.1 parsing, PSScriptAnalyzer, Pester, version/tag agreement, and exact-byte SHA-256 coverage. Filesystem and ZIP tests use real local files; ConfigMgr and network interactions are mocked.

**Live ConfigMgr, WinPE, and SMB validation remains pending.** Run the [environment rollout checklist](docs/validation.md#required-live-tests) before broad deployment. Check [CI](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/actions/workflows/ci.yml) for the status of a specific revision.

## Maintainer

**Claudio Mendes** · [@vartaxe](https://github.com/vartaxe) · [vartaxe@outlook.com](mailto:vartaxe@outlook.com)

See [authors and artwork notices](AUTHORS.md).

## Related projects

- [Add Computer to AD Group](https://github.com/vartaxe/ConfigMgr-OSD-AddComputerToADGroup) - companion task-sequence utility ([documentation](https://vartaxe.github.io/ConfigMgr-OSD-AddComputerToADGroup/)).
- [Claudio Mendes / vartaxe](https://vartaxe.github.io/vartaxe/) - profile and project directory ([GitHub](https://github.com/vartaxe)).

## License

MIT. See [LICENSE](LICENSE).
