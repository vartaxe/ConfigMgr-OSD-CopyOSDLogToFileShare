# Validation

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1` to parse every PowerShell file with Windows PowerShell 5.1, run PSScriptAnalyzer, and execute Pester tests.

## Prerequisites and scope

Install Pester 5 or later and PSScriptAnalyzer in the validation environment. CI installs Pester 5.5+ within major version 5 and PSScriptAnalyzer 1.22+.
The validator explicitly requires Windows PowerShell 5.1 and imports Pester with minimum version 5.
It analyzes `Scripts`, `Tests`, and `build`, checks `VERSION` against the production script's literal version assignment, and verifies `CHECKSUMS.txt`.
Parser errors, analyzer warnings/errors, missing modules, failed Pester discovery, zero discovered tests, failed tests, and manifest/version errors return a nonzero process exit.

```powershell
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
`.gitattributes` uses `* -text` so Git preserves exact bytes rather than silently converting line endings between the worktree and `git archive`.
Changing attributes does not retroactively repair bytes already normalized in an existing index or checkout. Stage the reviewed exact bytes, regenerate the manifest, and verify the candidate commit's archive and a fresh checkout as well as the working tree.
EditorConfig describes editing conventions, not hash normalization: regenerate the manifest after any byte change.

Neither checksums nor a CI pass authenticate a publisher or prove live deployment behavior. The validation illustration is not a test transcript.
Repository checks include source-pattern tests and behavioral tests using real filesystem copies and ZIP manifests; Task Sequence and network interactions are mocked.

## Required CI checks

The canonical `.github/workflows/ci.yml` workflow preserves both required branch-protection checks: `CI validation` and `PowerShell validation`.
`CI validation` runs the full Windows PowerShell 5.1 validator. `PowerShell validation` is a lightweight dependent status job, not a second validation run.
It passes only when `CI validation` succeeds and fails if that job fails, is cancelled, or is skipped. Its `always()` condition prevents a failed dependency from silently skipping the status job.
Keep both check names while branch protection requires them; deleting or renaming a required check leaves pull requests blocked.

## Pending live validation

Live testing remains pending for the current WinPE boot image, a full Windows Task Sequence, SMB3 encrypted and SMB2 compatibility destinations, wrong credentials, access denied, destination unavailability, interrupted uploads, archive retention after failure, and sanitized `CopyOSDLogs.log` and `smsts.log`.
