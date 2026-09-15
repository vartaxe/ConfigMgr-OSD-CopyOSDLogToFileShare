<p align="center"><img src="assets/banner.svg" alt="ConfigMgr OSD Copy Logs to File Share" width="100%"></p>

# ConfigMgr OSD Copy Logs to File Share

Collect, archive, and upload ConfigMgr OSD logs to an SMB share with retries, size verification, and CMTrace logging.

Version 1.0.0 is published as a prerelease; live ConfigMgr, WinPE, and SMB validation remains pending.

[Quick start](#quick-start) | [Deployment](docs/deployment.md) | [Compatibility](docs/compatibility.md) | [Security](SECURITY.md) | [Troubleshooting](docs/troubleshooting.md)

[![Version](https://img.shields.io/badge/version-1.0.0-2671be)](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/releases/tag/v1.0.0)
[![CI](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/actions/workflows/ci.yml/badge.svg)](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/actions/workflows/ci.yml)
![PowerShell](https://img.shields.io/badge/Windows%20PowerShell-5.1-2671be)
[![License](https://img.shields.io/badge/license-MIT-22c55e)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-%E2%9D%A4-db61a2)](https://github.com/sponsors/vartaxe)

## Quick start

Run the packaged PowerShell script only inside an active ConfigMgr Task Sequence using Windows PowerShell 5.1. PowerShell 7 is not a supported runtime.
Set `OSDLogFileShare` to a UNC destination and provide `OSDLogUserName` and a hidden `OSDLogPassword` immediately before the step:

```powershell
.\Scripts\Copy-OSDLogToFileShare.ps1
```

The standard profile runs without parameters. Add `-IncludeExtendedLogs` to the step's **Parameters** field when setup, servicing, update, or rollback troubleshooting requires extended logs.

Configure an external Task Sequence timeout and native cleanup steps that clear credentials **even when the script fails**.
The secure default may refuse WinPE or older SMB clients; do not enable compatibility exceptions without approval.
Read [deployment](docs/deployment.md) and [compatibility](docs/compatibility.md) before use.

## Why this project exists

Collecting logs after an operating system deployment should not require a large framework in a ConfigMgr Task Sequence. This PowerShell script keeps log collection, archiving, and SMB upload in one packaged utility, with explicit logging and compatibility controls.

## Highlights

- Self-contained PowerShell script with no third-party runtime module dependency
- Standard and opt-in extended log collection, `Manifest.json`, and local ZIP creation
- SMB upload retries and remote byte-size verification; local archive retention on upload failure
- Native CMTrace-format logging that prefers `_SMSTSLogPath`, with a Windows Temp (`%WINDIR%\Temp`) fallback
- Explicit process exit codes and ConfigMgr Task Sequence variables
- Secure defaults with visible, opt-in compatibility controls
- Windows PowerShell 5.1 validation, Pester tests, and an exact-byte SHA-256 source manifest

## Documentation

- [Architecture](docs/architecture.md)
- [Compatibility](docs/compatibility.md)
- [Deployment](docs/deployment.md)
- [Logging](docs/logging.md)
- [Release process](docs/release-process.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Validation](docs/validation.md)

## Validation status

Windows PowerShell 5.1 static analysis, mocked Pester tests, checksum validation, and [GitHub Actions validation](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/actions/runs/35004030520) passed for the published v1.0.0 revision. Later changes require their own validation.

Static checks and mocked unit tests do not prove live ConfigMgr, WinPE, or SMB behavior. No live platform is certified here.
See the [validation procedure and pending scenarios](docs/validation.md). CI badges report workflow state, not deployment certification.

## Maintainer

**Claudio Mendes** · [@vartaxe](https://github.com/vartaxe) · [vartaxe@outlook.com](mailto:vartaxe@outlook.com)

## License

MIT. See [LICENSE](LICENSE).
