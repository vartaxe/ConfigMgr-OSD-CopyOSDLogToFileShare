# Contributing

Keep contributions focused, readable, and safe for ConfigMgr task sequence use.

Before opening a pull request:

1. Install the pinned development modules and run `.\build\Invoke-Validation.ps1` in Windows PowerShell 5.1 as described in [validation](docs/validation.md).
2. Keep examples generalized.
3. Do not add organization-specific defaults.
4. Do not introduce credential logging.
5. Update documentation when behavior changes.
6. Add focused Pester coverage for behavioral fixes, and distinguish mocks from live tests.
7. Regenerate `CHECKSUMS.txt` after all file changes, including documentation and workflow updates, following the [checkout convention](docs/release-process.md#checksum-checkout-convention). Run validation again before pushing.
8. Check upstream licenses before reusing code or artwork, and preserve required attribution. Documentation inspiration does not grant permission to copy those assets.

`-SkipChecksums` skips only the validator's final manifest verification phase. Repository checksum tests still run, so the switch does not permit a complete validation run with a stale manifest. Regenerate `CHECKSUMS.txt` before running the complete validator, and omit the switch for final validation.

The production PowerShell script must remain self-contained, target Windows PowerShell 5.1, and retain secure defaults. Review analyzer warnings individually; any suppression needs a precise justification. Never include credentials or unsanitized logs in a pull request.

Record live environment results separately from static analysis and mocked tests. A regular release identifies a distribution, not a live-certified platform; earlier results do not validate later changes. Follow the [release process](docs/release-process.md), keep published artifacts unchanged, and use a new version for changed release content.

## Source conventions

- Use four-space indentation for PowerShell and SVG source, and two spaces for YAML. Preserve the line endings in `.gitattributes`: CRLF for `.ps1`, LF for other maintained text.
- Start production scripts and build helpers with `#Requires -Version 5.1`, followed by one blank line before comment-based help. Keep help before `CmdletBinding`, suppression attributes, and `param`. Check both AST-associated help and nonexecuting `Get-Help -Full`.
- Use the pinned PSScriptAnalyzer formatter for spacing and indentation. Review formatting separately from behavioral changes: preserve non-comment tokens, AST structure, requirements, literal strings, defaults, security decisions, and output streams.
- Indent Pester setup and nested test blocks to reflect their scope. Preserve fixture contents, assertions, and process timeouts. Comments should explain non-obvious constraints, not restate the code.
- Use **Windows PowerShell 5.1**, **PowerShell 7**, and **PowerShell script** consistently. Use **Configuration Manager** or **ConfigMgr** for the product, and lowercase **task sequence** in prose. Preserve exact UI labels.
- Use sentence-case headings and active verbs. Lead with the operator's next step and keep instructions concise, following [Microsoft's style and voice guidance](https://learn.microsoft.com/en-us/style-guide/top-10-tips-style-voice).

Keep diagrams static and self-contained, with Segoe UI/system sans-serif typography, the project's blue/teal palette, and legible light/dark surfaces. Separate step numbers from labels and target text contrast of at least 4.5:1, or 3:1 for large text. Retain meaningful titles, descriptions, explicit pending-status text, equivalent prose, and full-size links; use compact workflow variants when narrow layouts need them. Illustrations are never evidence of a test pass.
