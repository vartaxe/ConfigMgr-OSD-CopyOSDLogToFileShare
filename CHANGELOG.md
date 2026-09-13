# Changelog

## v1.0.0 (pre-release)

The supplied 1.0.0 utility is being prepared for review; no release or live-environment certification is claimed.

- Collect focused ConfigMgr OSD logs, create a manifest and ZIP, upload to SMB, and retain the local archive on upload failure.
- Correct pre-release defects in collection, logging, WinPE paths, archive uniqueness, and upload verification.
- Fail closed when SMB properties or authentication restrictions cannot be enforced, unless the relevant explicit compatibility exception is approved.
- Validate with Windows PowerShell 5.1 parsing, PSScriptAnalyzer, Pester, version checks, and exact-byte SHA-256 coverage.
- Document Task Sequence credential cleanup, external timeout, compatibility limits, and pending live validation.
