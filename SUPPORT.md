# Support

This project is provided as open-source tooling without guaranteed support.

Before opening an issue:

- Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1` using Windows PowerShell 5.1 in a clean source tree; see [validation prerequisites](docs/validation.md).
- Confirm the package was distributed to the required distribution points.
- Confirm the ConfigMgr Task Sequence step references the packaged PowerShell script.
- Sanitize logs before sharing.

Include the version, Windows/WinPE and ConfigMgr versions, selected parameters without credentials, saved exit code, and a minimal sanitized failure description. Distinguish a source-validation failure from a real deployment failure.

See the [v1.0.0 release notes](RELEASE-NOTES.md#v100), [troubleshooting guide](docs/troubleshooting.md), and [validation scope](docs/validation.md). A regular release does not replace testing in your deployment environment.
Report non-sensitive issues at [GitHub Issues](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/issues); report vulnerabilities through [Security](SECURITY.md).
