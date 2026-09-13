# Release process

Current scope is **pre-release review of version 1.0.0**. Do not merge, tag, or publish as part of this preparation.

1. Use `-SkipChecksums` only during source edits, then finish all changes.
2. Regenerate `CHECKSUMS.txt` for every maintained source file except the manifest itself, including dotfiles.
3. Run the [full validator](validation.md) without `-SkipChecksums`; optionally pass `-Tag v1.0.0` to check the proposed tag without creating it.
4. Verify the manifest against the worktree, an extracted `git archive`, and a fresh checkout of the exact candidate commit. Keep verification artifacts outside the source root.
5. Record static/unit results separately from pending [live scenarios](validation.md#pending-live-validation).
6. Obtain maintainer review and explicit approval before any future merge, tag, or release. Complete live validation before claiming platform compatibility.

Git's `* -text` attribute is intentional: checksums refer to exact stored bytes, not normalized text.
Do not re-enable automatic line-ending conversion without changing and verifying the manifest strategy.
CI has read-only contents permissions and validates tags; it does not publish releases.
