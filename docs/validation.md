---
title: Validation
---

# Validation

[Documentation home](../index.md) | [Development](development.md) | [Deployment](deployment.md) | [Compatibility](compatibility.md) | [Validation](validation.md)

<p align="center"><img src="../assets/validation-pass.svg" alt="Illustrative checklist, not a test result: parser, analyzer, Pester, versions, and SHA-256 checks are required; live ConfigMgr, WinPE, and SMB validation remains pending" width="920" height="360"></p>

[View the full-size validation checklist](../assets/validation-pass.svg). The commands and requirements below provide the equivalent text.

The automated suite checks source integrity and isolated behavior. ConfigMgr, WinPE, and real SMB operations are not executed by these tests.

## Prerequisites and scope

Use the same pinned development modules as CI: Pester 5.7.1 and PSScriptAnalyzer 1.25.0. The validator explicitly requires Windows PowerShell 5.1 and those exact module versions.
Use an approved package source and trust policy; do not bypass publisher verification.
It analyzes `Scripts`, `Tests`, and `build`, checks `VERSION` against the production script's literal version assignment, and verifies `CHECKSUMS.txt`.
Parser errors, analyzer warnings/errors, missing modules, failed, skipped, or not-run Pester tests, failed discovery, zero discovered tests, and manifest/version errors return a nonzero process exit.

If the modules are missing, install them from your approved source and trust policy:

```powershell
Install-Module Pester -RequiredVersion '5.7.1' -Repository PSGallery -Scope CurrentUser -Force
Install-Module PSScriptAnalyzer -RequiredVersion '1.25.0' -Repository PSGallery -Scope CurrentUser -Force
```

## Run automated validation

After reviewing and normalizing all changes, regenerate the source manifest using the [checksum recipe](release-process.md#checksum-checkout-convention), then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1 -Tag v1.0.0
```

`-Tag` verifies metadata agreement; it does not create a tag. Omitting it still runs all other checks.
`-SkipChecksums` skips only the final manifest phase, not the checksum tests inside Pester. It is not a way to validate a stale manifest.

The manifest covers all files in the source root, including dotfiles, excluding only root `.git` metadata and `CHECKSUMS.txt` itself.
Each line is a SHA-256 hash, two spaces, then a root-relative path using forward slashes.
Duplicate, missing, extra, malformed, and mismatched entries fail. Validate a clean source tree or full extracted source archive; keep generated ZIPs and test artifacts outside that tree.
`.gitattributes` requires CRLF for `.ps1` and LF for other maintained text. Preserve UTF-8 without a BOM. The existing `git archive` flow honors these attributes. Verify the worktree, a fresh checkout, and the extracted release package against the same manifest; check the actual bytes rather than assuming an archive mismatch.

Neither checksums nor a CI pass authenticate a publisher or prove live deployment behavior. The validation illustration is not a test transcript.
Repository checks include source-pattern tests and behavioral tests using real filesystem copies and ZIP manifests; Task Sequence and network interactions are mocked.
Documentation checks cover local Markdown/image targets, heading anchors, the Pages configuration and source-link contract, and accessible SVG metadata. These checks do not replace a real Jekyll build or rendered-browser review.
Coverage includes literal-path copies, manifests and ZIP contents, WinPE path selection, input validation, log redaction, secure SMB decisions, credential binding, retries, byte-size verification, and cleanup/retention.
The v1.0.0 regressions exercise existing-archive preservation, early mapping-argument cleanup, safe inspection-failure classification, earlier-run retention, and ZIP-creation failure. Six defect-focused cases were observed failing before their fixes and passing afterward; they are local or mocked tests, not live OSD evidence.
Child-process fixtures also verify that parser, analyzer, discovery, skipped/empty tests, version, tag, and checksum errors fail the validator rather than produce a successful exit.

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

The release workflow produces a prerelease candidate, not final regular/latest approval. Downloaded assets and extracted source must pass verification before the maintainer explicitly approves promotion of the same release. Follow the [two-stage release process](release-process.md#publish-only-after-approval); neither stage replaces environment testing.

## Required live tests

All environment checks below remain **pending**. A regular release, local test pass, or CI pass does not complete them.

| Pilot scenario | Record before broad rollout |
|---|---|
| Full Windows and current WinPE task sequences | Exact package/image versions, Windows PowerShell 5.1, Local System context, COM environment, and correct persistent `OSDisk` selection |
| Secure SMB3 destination | Correct identity, encryption/integrity, and separately verified authentication policy; `Get-SmbConnection` alone does not prove Kerberos/NTLM negotiation |
| Approved compatibility exceptions, if needed | Exact switches, image cmdlet capabilities, existing NTLMv2-only policy, and observed connection properties |
| Wrong credentials, access denied, and unavailable destination | Bounded retry count, useful sanitized failure, owned-connection cleanup, and retained local evidence |
| Interrupted transfer and verification failure | Remote partial-file handling and readable retained ZIP/staging under `Windows\Temp\PendingOSDLogs` on the selected volume |
| Successful delivery and cleanup | Remote byte-size match, readable archive and manifest, expected sources, current-run cleanup, and earlier archives left intact |
| External timeout and result propagation | Native credential cleanup where execution continues, saved nonzero result, and no failure hidden by cleanup |
| Sensitive-data review | Dedicated log and `smsts.log` contain no supplied credentials; manifest error details are sanitized; copied diagnostics are handled as sensitive data |

Keep raw logs private. Record only sanitized evidence and non-sensitive environment versions. See [compatibility](compatibility.md) for candidate platforms and [security](../SECURITY.md) for limitations.

## Documentation site checks

GitHub Pages publishes `main` from the repository root using Cayman and the shared layout. `index.md` is a focused landing page rather than a README include. Markdown guides use relative source links; `jekyll-relative-links` rewrites those to their generated page URLs. Keep explicit YAML front matter on `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`: `jekyll-optional-front-matter` excludes these standard filenames from automatic conversion.
The examples index has an explicit `/examples/` permalink so README-index behavior cannot change its destination. Script and extensionless `LICENSE` links remain static resources; `Tests` and `build` are excluded from the site, not the source repository or release archives.

The Pages deployment-guide button uses `/docs/deployment.html` through `relative_url`, preserving the project base path. Keep `.md` links in Markdown, not HTML/Liquid navigation. Each guide has a relative link back to the documentation home so GitHub and Pages both remain navigable.
The shared layout, CSS, and favicon match the [profile site](https://vartaxe.github.io/vartaxe/) and companion AD-group project. Coordinate shared-template changes across all three repositories.

After changing site content, check the GitHub Pages build and rendered light/dark desktop/mobile pages, including keyboard focus and the skip link.
Generated `_site`, `.jekyll-cache`, `.jekyll-metadata`, `.sass-cache`, `.bundle`, and `vendor/bundle` paths are ignored by Git, but the strict checksum validator still sees files in the source tree. Keep local build output and caches outside the tree, or remove only known generated artifacts before checksum regeneration and final validation.
