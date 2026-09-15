# Support

This project is provided as open-source tooling without guaranteed support.

Before opening an issue:

- Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1` using Windows PowerShell 5.1 in a clean source tree; see [validation prerequisites](docs/validation.md).
- Confirm the package was distributed to the required distribution points.
- Confirm the ConfigMgr Task Sequence step references the packaged PowerShell script.
- Sanitize logs before sharing.

Version 1.0.0 is published as a [GitHub prerelease](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/releases/tag/v1.0.0). Live ConfigMgr, WinPE, and SMB validation remains pending; no live test pass is claimed.
Report non-sensitive issues at [GitHub Issues](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/issues); report vulnerabilities through [Security](SECURITY.md).
