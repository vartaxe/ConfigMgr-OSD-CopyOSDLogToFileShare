# Validation

<p align="center"><img src="../assets/validation-pass.svg" alt="Validation checklist showing required parser, PSScriptAnalyzer, and Pester checks with live ConfigMgr and WinPE tests marked PENDING" width="70%"></p>

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1` to parse every PowerShell file with Windows PowerShell 5.1, run PSScriptAnalyzer, and execute Pester tests.

## Prerequisites and scope

Install the same pinned development modules used by CI: Pester 5.7.1 and PSScriptAnalyzer 1.25.0. The validator explicitly requires Windows PowerShell 5.1 and those exact module versions, so an upstream module release cannot silently change validation results.
Use an approved package source and trust policy; do not bypass publisher verification.
It analyzes `Scripts`, `Tests`, and `build`, checks `VERSION` against the production script's literal version assignment, and verifies `CHECKSUMS.txt`.
Parser errors, analyzer warnings/errors, missing modules, failed, skipped, or not-run Pester tests, failed discovery, zero discovered tests, and manifest/version errors return a nonzero process exit.

```powershell
Install-Module Pester -RequiredVersion '5.7.1' -Repository PSGallery -Scope CurrentUser -Force
Install-Module PSScriptAnalyzer -RequiredVersion '1.25.0' -Repository PSGallery -Scope CurrentUser -Force
Import-Module Pester -RequiredVersion '5.7.1' -Force
Import-Module PSScriptAnalyzer -RequiredVersion '1.25.0' -Force

# Final validation; checksums are required.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1

# Optional tag check (does not create a tag).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1 -Tag v1.0.0

# Developer loop only, before regenerating CHECKSUMS.txt.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1 -SkipChecksums
```

The manifest covers all files in the source root, including dotfiles, excluding only root `.git` metadata and `CHECKSUMS.txt` itself.
Each line is a SHA-256 hash, two spaces, then a root-relative path using forward slashes.
Duplicate, missing, extra, malformed, and mismatched entries fail. Validate a clean source tree or full extracted source archive; keep generated ZIPs and test artifacts outside that tree.
`.gitattributes` normalizes PowerShell `.ps1` files to CRLF and Markdown, YAML, SVG, `LICENSE`, and `VERSION` to LF. Regenerate the manifest after any content or line-ending change, then verify the candidate commit's archive and a fresh checkout as well as the working tree.
EditorConfig describes editing conventions, not hash normalization: regenerate the manifest after any byte change.

Neither checksums nor a CI pass authenticate a publisher or prove live deployment behavior. The validation illustration is not a test transcript.
Repository checks include source-pattern tests and behavioral tests using real filesystem copies and ZIP manifests; Task Sequence and network interactions are mocked.

## Required CI checks

The canonical `.github/workflows/ci.yml` workflow preserves both required branch-protection checks: `CI validation` and `PowerShell validation`.
`CI validation` runs the full Windows PowerShell 5.1 validator. `PowerShell validation` is a lightweight dependent status job, not a second validation run.
It passes only when `CI validation` succeeds and fails if that job fails, is cancelled, or is skipped. Its `always()` condition prevents a failed dependency from silently skipping the status job.
Keep both check names while branch protection requires them; deleting or renaming a required check leaves pull requests blocked.
`CI validation` checks out without persisted credentials and derives `-Tag` from `GITHUB_REF` on tag pushes, so tag and version agreement is verified inside the same job rather than a separate workflow.

## What each result establishes

| Validation layer | Evidence and limits |
|---|---|
| Static | Parser/analyzer results apply to the checked source and runtime; they do not exercise ConfigMgr, WinPE, or SMB |
| Unit / mocked | Pester checks source contracts and isolated behavior with test doubles; mocks do not establish live authentication, SMB dialect, permissions, or deployment compatibility |
| GitHub Actions | The [CI run](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/actions/workflows/ci.yml) must complete for the relevant commit before claiming a CI pass; Windows-hosted CI is not a domain/ConfigMgr lab |
| Live | Only recorded testing in a real ConfigMgr/WinPE/SMB environment establishes the results below |

No static success illustration or workflow definition is evidence of a passed run. Record the exact revision, commands, engine/module versions, results, and any unresolved warnings when reporting validation.

## Required live tests

**All tests below are PENDING. No live environment results are recorded for this version.**

| Required live test | Status | Evidence required |
|---|---|---|
| WinPE Task Sequence execution | **PENDING** | Packaged script runs as Local System in WinPE with Windows PowerShell 5.1 and valid `OSDisk` pointing to the offline OS volume |
| Full Windows Task Sequence execution | **PENDING** | Packaged script runs in full Windows operating system phase; active `Microsoft.SMS.TSEnvironment` |
| SMB3 encrypted destination | **PENDING** | Default upload to SMB 3.x share with SMB encryption and signing verified |
| SMB2 compatibility destination | **PENDING** | Explicit `-MinimumSmbDialect SMB2 -AllowUnencryptedSmb` connects and logs compatibility warnings |
| Invalid credentials | **PENDING** | Bad credentials fail safely without leaking secret strings to logs |
| Destination share unavailable | **PENDING** | Preflight TCP 445 check fails fast and logs the error; retries handled within configured count |
| Access denied on share | **PENDING** | Upload permission denial fails safely, removes mapping, and retains local archive |
| Local archive retention | **PENDING** | Local zip in `PendingOSDLogs-*` remains intact and readable after upload failure |
| Remote byte-size verification | **PENDING** | Upload verifies remote file size matches local archive length before removing local files |
| Sanitized dedicated log | **PENDING** | `CopyOSDLogs.log` contains no cleartext passwords or credentials across success and failure paths |
| Sanitized ConfigMgr log | **PENDING** | Corresponding `smsts.log` contains no credentials or sensitive parameters |
| Sanitized archive manifest | **PENDING** | `Manifest.json` contains no credential strings or raw exception diagnostics when source collection fails |
| Credential cleanup and failure propagation | **PENDING** | Custom Task Sequence variables cleared on both success and failure; failed script result preserved |

Keep raw logs private. Record only sanitized evidence and non-sensitive environment versions. See [compatibility](compatibility.md) for candidate platforms and [security](../SECURITY.md) for limitations.
