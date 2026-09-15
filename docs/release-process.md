# Release process

Version 1.0.0 is already published as a [GitHub prerelease](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/releases/tag/v1.0.0). Live ConfigMgr, WinPE, and SMB validation remains pending; publication does not establish platform compatibility.

The steps below are for future releases. Preparing, reviewing, or validating changes does not authorize merging, tagging, or publishing. Obtain maintainer review and explicit approval before each of those actions.

## Prepare a future release

1. Select the intended three-part numeric version and keep `VERSION`, the production PowerShell script's version metadata, and `CHANGELOG.md` consistent. `vX.Y.Z` is a placeholder: replace `X`, `Y`, and `Z` with the intended numeric version before passing `-Tag` or creating a tag. The literal `vX.Y.Z` is not valid validator input.
2. Add a nonempty `## vX.Y.Z` section to `RELEASE-NOTES.md`, substituting the intended numeric tag. The `Release` workflow publishes only that exact version section and fails if it is missing or empty.
3. Use Windows PowerShell 5.1 with the pinned Pester 5.7.1 and PSScriptAnalyzer 1.25.0 modules from an approved package source and trust policy. Follow the [validation prerequisites](validation.md#prerequisites-and-scope); do not bypass publisher verification.
4. Finish all maintained file changes. Use `-SkipChecksums` only during the developer loop, then regenerate `CHECKSUMS.txt` last using the [checkout convention](#checksum-checkout-convention).
5. Run the [full validator](validation.md) without `-SkipChecksums`, then repeat with `-Tag` and the intended numeric tag to verify version agreement. This check does not create a tag.
6. Before tagging, verify a clean, committed revision: `git status --porcelain` must be empty. Record the exact commit SHA and verify the manifest against the worktree, an extracted `git archive` of that commit, and a fresh checkout of that same commit. Keep archives, logs, and other verification artifacts outside the source root.
7. Record the revision, commands, Windows PowerShell/module versions, static analysis, mocked test results, checksum results, and GitHub Actions results separately from pending [live scenarios](validation.md#required-live-tests). Complete and record live validation before claiming platform compatibility.

## Publish only after approval

Pushing an approved numeric `vX.Y.Z` tag starts publication through `.github/workflows/release.yml`. Its trigger pattern is `v*.*.*`, but validation requires a three-part numeric tag matching `VERSION` and the PowerShell script. Alternatively, manually dispatch the workflow with an **existing tag**; dispatch is not a way to create a tag.

Avoid a branch with the same name as a release tag. Before publication, confirm the tag points to the reviewed commit. Release checkout and `git archive` explicitly select `refs/tags/<tag>`, not an ambiguous short name, so a same-named branch cannot supply different code.

The release workflow runs the full validator against the tagged revision, then packages a `git archive` ZIP and its SHA-256 sidecar as `<Project>-v<Version>.zip` and `<Project>-v<Version>.zip.sha256`. For this repository, `<Project>` is `ConfigMgr-OSD-CopyOSDLogToFileShare`; `<Version>` is the numeric version without the leading `v`.

Publication uses `--verify-tag` to require the remote tag to exist, preventing release creation from creating a tag, and `--prerelease` to publish a GitHub prerelease. Verify the workflow result, published assets, and sidecar hash before announcing the release.
CI remains separate: `.github/workflows/ci.yml` has read-only contents permission, validates tags, and does not publish releases. Only the release workflow has `contents: write`.

## Preserve published artifacts

The published v1.0.0 tag, ZIP, and SHA-256 sidecar are immutable. Do not move or recreate the tag, overwrite the assets, or dispatch v1.0.0 to repackage later changes.
Documentation-only updates on `main` are not repackaged into the old ZIP. They do not require a new version entry or imply a new release.

Maintainer-approved edits to the public GitHub release body may clarify status or documentation links independently of the immutable `RELEASE-NOTES.md` snapshot in the tag and ZIP. Those differences do not change the tagged artifacts or establish live certification.

## Checksum checkout convention

`CHECKSUMS.txt` hashes the **checked-out file bytes** of every maintained file, including dotfiles, excluding only root `.git` metadata and the manifest itself.
Follow `.gitattributes`: PowerShell `.ps1` files use **CRLF**; other text files use **LF**, including Markdown, YAML, SVG, `LICENSE`, and `VERSION`. These repository rules avoid dependence on a contributor's global `core.autocrlf` setting.

Regenerate hashes after any content or line-ending change. Each manifest line contains a SHA-256 hash, exactly two spaces, and a root-relative path using `/`. Preserve deterministic hash-then-path sorting and write the manifest as UTF-8 without a BOM, with LF line endings and a final newline.
Final validation must check complete coverage and exact bytes without `-SkipChecksums`; do not weaken checks to accommodate an uncommitted release revision or generated files in the source root.
