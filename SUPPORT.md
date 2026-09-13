# Support

This project is provided as open-source tooling without guaranteed support.

Before opening an issue:

- Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1` in a clean source tree; see [validation prerequisites](docs/validation.md).
- Confirm the package was distributed to the required distribution points.
- Confirm the Task Sequence step references the packaged script.
- Sanitize logs before sharing.

Version 1.0.0 is a pre-release candidate. No live ConfigMgr, WinPE, or SMB test pass is claimed.
Report non-sensitive issues at [GitHub Issues](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/issues); report vulnerabilities through [Security](SECURITY.md).
