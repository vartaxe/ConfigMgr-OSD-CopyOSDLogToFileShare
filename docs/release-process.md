# Release process

Current scope is **pre-release review of version 1.0.0**. Do not merge, tag, or publish as part of this preparation.

1. Use `-SkipChecksums` only during source edits, then finish all changes.
2. Regenerate `CHECKSUMS.txt` for every maintained source file except the manifest itself, including dotfiles.
3. Run the [full validator](validation.md) without `-SkipChecksums`; optionally pass `-Tag v1.0.0` to check the proposed tag without creating it.
4. Verify the manifest against the worktree, an extracted `git archive`, and a fresh checkout of the exact candidate commit. Keep verification artifacts outside the source root.
5. Record static/unit results separately from pending [live scenarios](validation.md#required-live-tests).
6. Obtain maintainer review and explicit approval before any future merge, tag, or release; pushing a version tag now starts publication, so approval must come first. Complete live validation before claiming platform compatibility.
7. Add a `## vX.Y.Z` section to `RELEASE-NOTES.md`. The `Release` workflow publishes only that version section and fails if it is missing or empty.

## Checksum checkout convention

`CHECKSUMS.txt` hashes the **checked-out file bytes**. Follow `.gitattributes`: PowerShell `.ps1` files use **CRLF**; other text files use **LF**, including Markdown, YAML, SVG, `LICENSE`, and `VERSION`. These repository rules avoid dependence on a contributor's global `core.autocrlf` setting.
CI keeps read-only contents permission, validates tags, and does not publish releases.
Publishing is a separate `.github/workflows/release.yml` workflow with `contents: write`, triggered only by a maintainer-pushed `v*.*.*` tag or manual dispatch.
It re-runs the validator against the tagged revision with `-Tag`, then publishes a GitHub prerelease holding a `git archive` zip and its SHA-256 sidecar, using `--verify-tag` so a missing or mismatched tag fails.
Publication does not change release status: v1.0.0 stays a pre-release candidate until live validation is complete.
