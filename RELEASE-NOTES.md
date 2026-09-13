# Release notes

## v1.0.0

The supplied `Copy-OSDLogToFileShare.ps1` remains version 1.0.0. No tag, published release, or live validation is implied.

Highlights:

- Targets WinPE and full Windows Task Sequences; live validation remains pending
- Generic UNC destination support
- Standard and extended collection profiles
- Manifest.json
- Local ZIP creation
- TCP 445 preflight
- SMB upload with remote-size verification
- Local archive retention after failed upload
- Dedicated Task Sequence logging

Pre-release fixes cover collection and logging correctness, offline Windows paths, unique archive names, secure SMB checks, and upload ownership/size verification.
Defaults may refuse older clients and WinPE; [compatibility exceptions](docs/compatibility.md) require explicit approval and do not change Windows security policy.

The validator checks Windows PowerShell 5.1 syntax, analyzer findings, Pester discovery/results, version consistency, and the SHA-256 source manifest.
The SVG validation checklist is illustrative, not evidence of passing tests.
See [validation](docs/validation.md) for commands and all pending live scenarios.
