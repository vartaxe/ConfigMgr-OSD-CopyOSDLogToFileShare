---
title: Copy OSD Logs to File Share
description: Deployment, compatibility, security, and validation guidance for copying ConfigMgr OSD logs to an SMB share.
---

## <img src="assets/folder-arrow-right.svg" alt="" aria-hidden="true" width="24" height="24"> Collect deployment logs

Copy OSD Logs to File Share collects a focused set of deployment logs, writes a manifest, creates a local ZIP, and uploads it to an authenticated SMB destination. Failed uploads retain the local archive; successful uploads verify remote byte size, not a content hash.

> **Current version: 1.0.0.** This site follows `main`; the
> [v1.0.0 release](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/releases/tag/v1.0.0)
> is a versioned snapshot with its own [release notes](RELEASE-NOTES.md).

## Before deployment

Live ConfigMgr, WinPE, and SMB testing was not executed. Complete the
[environment-validation checklist](docs/validation.md#required-live-tests) before broad deployment.

1. Read the [deployment guide](docs/deployment.md) for package setup, variables, retry limits, and an external Task Sequence timeout.
2. Check [compatibility](docs/compatibility.md) before approving exceptions. The secure default requires SMB3, integrity, and encryption, and refuses unverifiable connections.
3. Follow the [security requirements](SECURITY.md): hide passwords, disable parameter logging, and use native cleanup steps on **success and failure** while preserving the script result.

Run only in an active ConfigMgr Task Sequence as Local System with **Windows PowerShell 5.1**. PowerShell 7 is not a supported Task Sequence runtime. WinPE requires the appropriate PowerShell/.NET components and may need explicitly approved SMB compatibility settings.

## Documentation

| Guide | Use it for |
|---|---|
| [Deployment](docs/deployment.md) | Task Sequence layout, variables, parameters, and credential lifecycle |
| [Compatibility](docs/compatibility.md) | Supported runtime targets and opt-in SMB exceptions |
| [Security](SECURITY.md) | Least privilege, credential limitations, private reporting |
| [Validation](docs/validation.md) | Reproducible static/mocked checks and pending live scenarios |
| [Architecture](docs/architecture.md) | Collection, manifest, ZIP, upload, and cleanup sequence |
| [Logging](docs/logging.md) | CMTrace diagnostics, retained archives, and sensitive source logs |
| [Troubleshooting](docs/troubleshooting.md) | Upload failures, timeouts, WinPE storage, and checksums |
| [Examples](examples/README.md) | Placeholder Task Sequence configuration |
| [Release process](docs/release-process.md) | Source-byte checksums and publication safeguards |
| [Development](docs/development.md) | Workstation setup, names versus paths, and shared banner generation |
| [Distribution](docs/distribution.md) | Release packages, standalone gist, licensing, and checksum verification |

## Outputs and results

Exit `0` means the remote byte size was verified and local cleanup completed.
Exit `1` means collection, archiving, upload, or cleanup failed. Optional source
failures are recorded in the manifest without necessarily failing delivery.
Previous retained runs are not automatically retried or pruned.
See the [exit-code contract](docs/logging.md#exit-codes).

## Source and releases

Use the [source repository](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare) for the maintained script, tests, and contribution guidance. The [PowerShell source](Scripts/Copy-OSDLogToFileShare.ps1) is also available directly; download the complete package when following the deployment guide.

For the standalone script, use the
[public gist snapshot](https://gist.github.com/vartaxe/cd41f830cddc7853f5189713421a601b)
with its MIT license and checksums. The repository remains authoritative; see
[distribution](docs/distribution.md) before using a separately downloaded script.

Download the versioned ZIP and matching SHA-256 sidecar from
[GitHub Releases](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/releases).
Existing downloads do not update automatically.

For changes, see [contributing](CONTRIBUTING.md) and the
[release process](docs/release-process.md). Maintained by
[Claudio Mendes (@vartaxe)](https://github.com/vartaxe), under the
[MIT license](LICENSE).

## Related projects

- [Add Computer to AD Group](https://github.com/vartaxe/ConfigMgr-OSD-AddComputerToADGroup) - companion task-sequence utility ([documentation](https://vartaxe.github.io/ConfigMgr-OSD-AddComputerToADGroup/)).
- [Claudio Mendes / vartaxe](https://vartaxe.github.io/vartaxe/) - profile and project directory ([GitHub](https://github.com/vartaxe)).
