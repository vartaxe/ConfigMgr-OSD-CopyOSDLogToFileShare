# Contributing

Contributions are welcome when they keep the project focused, readable, and safe for ConfigMgr Task Sequence use.

Before opening a pull request:

1. Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1` with Pester 5.7.1 and PSScriptAnalyzer 1.25.0 installed.
2. Keep examples generalized.
3. Do not add organization-specific defaults.
4. Do not introduce credential logging.
5. Update documentation when behavior changes.

Use `-SkipChecksums` only during the developer loop. Regenerate the manifest after final edits and run full validation without that switch.
Follow [`.gitattributes`](.gitattributes): PowerShell `.ps1` files use CRLF and other text files use LF. Regenerate `CHECKSUMS.txt` after every byte change; see [validation](docs/validation.md).
Record live environment results separately from mocked tests. Do not represent the pre-release 1.0.0 candidate as a published or live-certified release.
