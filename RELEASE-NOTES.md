# Release notes

## v1.0.0

Version 1.0.0 was published as a GitHub prerelease. Live ConfigMgr, WinPE, and SMB validation remains pending; no live platform certification is claimed.

### Reissue: 2026-09-20

This maintainer-authorized prerelease reissue replaces the tag, ZIP, and SHA-256 sidecar first published on 2026-09-15. It includes the merged documentation and diagram improvements, discoverable PowerShell help, and consistent source formatting. Version remains 1.0.0; log-collection behavior, credential handling, and security defaults are unchanged.

Previously downloaded copies do not update automatically and have different contents under the same version number. Download the ZIP and sidecar together and verify the new SHA-256. The release page records the exact reissued commit and archive hash.

For identification, the original archive SHA-256 was `C738B6BE6FFD5FBB554681F2579297A6CC0C2CD88AF418846E25789B25385FCD`. Its tag previously selected commit `ab0291ffb7cd22341df21b5ddb7ec3313c0bdba0`. Neither identifies this reissue.

### Highlights

- Targets ConfigMgr Task Sequence execution in WinPE and full Windows; live validation remains pending
- Generic UNC destination support
- Standard and extended collection profiles
- `Manifest.json`
- Local ZIP creation
- TCP 445 preflight
- SMB upload with remote-size verification
- Local archive retention after failed upload
- Dedicated CMTrace-format Task Sequence logging

Fixes before publication addressed collection and logging correctness, offline Windows paths, unique archive names, secure SMB checks, and upload ownership/size verification.

### Requirements

Use Windows PowerShell 5.1 in an active ConfigMgr Task Sequence, with PowerShell/.NET components in WinPE where applicable. PowerShell 7 is not a supported runtime.
Supply the UNC destination through `OSDLogFileShare` and credentials through `OSDLogUserName` and a hidden `OSDLogPassword`. Configure an external task sequence timeout and native credential cleanup on success and failure.
Defaults may refuse older clients and WinPE; [compatibility exceptions](docs/compatibility.md) require explicit approval and do not change Windows security policy.

### Validation status

Windows PowerShell 5.1 static analysis, mocked Pester tests, checksum validation, and GitHub Actions validation passed for the published v1.0.0 revision, not for unverified later changes.
The SVG validation checklist is illustrative, not evidence of passing tests.

### Documentation

See [deployment](docs/deployment.md) for setup, [security](SECURITY.md) for requirements and reporting, and [validation](docs/validation.md) for commands and all pending live scenarios.
