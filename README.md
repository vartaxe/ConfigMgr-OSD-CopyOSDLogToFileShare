<p align="center"><img src="assets/banner.svg" alt="ConfigMgr OSD Copy Logs to File Share" width="100%"></p>

# ConfigMgr OSD Copy Logs to File Share

Collect, archive, and upload ConfigMgr OSD logs to an SMB share with retries, size verification, and CMTrace logging.
Version **1.0.0 is pre-release**; live ConfigMgr, WinPE, and SMB validation is pending.

[Quick start](#quick-start) · [Deployment](docs/deployment.md) · [Compatibility](docs/compatibility.md) · [Security](SECURITY.md) · [Troubleshooting](docs/troubleshooting.md)

[![Version](https://img.shields.io/badge/version-1.0.0-2671be)](VERSION)
[![CI](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/actions/workflows/ci.yml/badge.svg)](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/actions/workflows/ci.yml)
![PowerShell](https://img.shields.io/badge/Windows%20PowerShell-5.1-2671be)
[![License](https://img.shields.io/badge/license-MIT-22c55e)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-%E2%9D%A4-db61a2)](https://github.com/sponsors/vartaxe)

## Quick start

Run only inside an active ConfigMgr Task Sequence using Windows PowerShell 5.1 and the packaged script.
Set `OSDLogFileShare`, `OSDLogUserName`, and hidden `OSDLogPassword` variables immediately before the step:

```powershell
.\Scripts\Copy-OSDLogToFileShare.ps1
```

Configure an external Task Sequence timeout and native cleanup steps that clear credentials **even when the script fails**.
The secure default may refuse WinPE or older SMB clients; do not enable compatibility exceptions without approval.
Read [deployment](docs/deployment.md) and [compatibility](docs/compatibility.md) before use.

## Why this project exists

ConfigMgr task sequences often need small operational helpers that remain understandable, self-contained, compatible with Windows PowerShell 5.1, and useful in older enterprise environments. This project provides one focused utility with explicit logging, verification, and compatibility behavior.

## Highlights

- Self-contained production script with no third-party runtime module dependency
- Native CMTrace-format logging under `_SMSTSLogPath`
- Explicit process exit codes and ConfigMgr task sequence variables
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

Static checks and mocked unit tests do not prove live ConfigMgr, WinPE, or SMB behavior. No live platform is certified here.
See the [validation procedure and pending scenarios](docs/validation.md). CI badges report workflow state, not deployment certification.

## Maintainer

**Claudio Mendes** · [@vartaxe](https://github.com/vartaxe) · [vartaxe@outlook.com](mailto:vartaxe@outlook.com)

## License

MIT. See [LICENSE](LICENSE).
