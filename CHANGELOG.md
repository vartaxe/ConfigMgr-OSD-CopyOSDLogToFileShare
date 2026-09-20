# Changelog

## v1.0.0 (prerelease)

### Reissue: 2026-09-20

- Maintainer-authorized replacement of the existing v1.0.0 tag and release ZIP/sidecar with one validated revision; previous downloads remain unchanged.
- Include the merged help, source-formatting, documentation, and accessible-diagram improvements without changing runtime behavior or security defaults.
- See the [reissue notice](RELEASE-NOTES.md#reissue-2026-09-20) for the original artifact identity and replacement guidance. Live validation remains pending.

### Initial publication: 2026-09-15

Initial GitHub prerelease. Static analysis, mocked tests, checksum validation, and GitHub Actions validation passed for the published v1.0.0 revision. Live ConfigMgr, WinPE, and SMB validation remains pending; those checks do not establish live-environment certification.

- Collect focused ConfigMgr OSD logs, create a manifest and ZIP, upload to SMB, and retain the local archive on upload failure.
- Correct defects in collection, logging, WinPE paths, archive uniqueness, and upload verification.
- Fail closed when SMB properties or authentication restrictions cannot be enforced, unless the relevant explicit compatibility exception is approved.
- Validate with Windows PowerShell 5.1 parsing, PSScriptAnalyzer, Pester, version checks, and exact-byte SHA-256 coverage.
- Document ConfigMgr Task Sequence credential cleanup, external timeout, compatibility limits, and pending live validation.
