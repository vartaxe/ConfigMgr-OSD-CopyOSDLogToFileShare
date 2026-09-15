# Changelog

## v1.0.0 (prerelease)

Initial GitHub prerelease. Static analysis, mocked tests, checksum validation, and GitHub Actions validation passed for the published v1.0.0 revision. Live ConfigMgr, WinPE, and SMB validation remains pending; those checks do not establish live-environment certification.

- Collect focused ConfigMgr OSD logs, create a manifest and ZIP, upload to SMB, and retain the local archive on upload failure.
- Correct defects in collection, logging, WinPE paths, archive uniqueness, and upload verification.
- Fail closed when SMB properties or authentication restrictions cannot be enforced, unless the relevant explicit compatibility exception is approved.
- Validate with Windows PowerShell 5.1 parsing, PSScriptAnalyzer, Pester, version checks, and exact-byte SHA-256 coverage.
- Document ConfigMgr Task Sequence credential cleanup, external timeout, compatibility limits, and pending live validation.
