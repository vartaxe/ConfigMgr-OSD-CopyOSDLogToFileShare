---
title: Release process
---

# Release process

[Documentation home](../index.md) | [Development](development.md) | [Deployment](deployment.md) | [Compatibility](compatibility.md) | [Validation](validation.md)

Publish **v1.0.0** as a prerelease candidate. Verify its downloaded assets, then obtain explicit maintainer approval to promote the same release to **regular/latest**. Distribution status does not establish live platform compatibility.

## Prepare a release

1. Keep `VERSION`, both production-script version literals, badges, examples, and the current changelog aligned to the intended three-part numeric version.
2. Add a nonempty `## v1.0.0` section to `RELEASE-NOTES.md` for this release. The workflow selects the exact tag's section. For a later version, replace the numeric version everywhere it identifies current release content.
3. Use Windows PowerShell 5.1 with pinned Pester 5.7.1 and PSScriptAnalyzer 1.25.0 modules from an approved source; do not bypass publisher verification. See [validation prerequisites](validation.md#prerequisites-and-scope).
4. Finish all changes, normalize maintained text to the [checkout convention](#checksum-checkout-convention), and regenerate `CHECKSUMS.txt` **last**.
5. Run the full validator with `-Tag v1.0.0` and without `-SkipChecksums`. This verifies version agreement without creating a tag.
6. Before publication, validate the exact committed revision, a fresh checkout, and the **extracted release ZIP**. The existing `git archive` flow honors this repository's `.gitattributes`. Check the produced file bytes against the manifest rather than inferring them from Git's stored blobs.
7. Record commands, engine/module versions, test counts, and checksum results. Report CI for the exact revision separately from local checks and the [live rollout checklist](validation.md#required-live-tests).

## Publish only after approval

Preparing or validating changes does not authorize merging, tagging, publishing a candidate, or promoting it. Obtain maintainer approval for each action. The workflow does not publish the final regular/latest release by itself.

### Stage 1: publish the prerelease candidate

Pushing an approved numeric tag starts `.github/workflows/release.yml`; a manual dispatch must select an **existing tag**. The `v*.*.*` trigger is broader than the validator, which requires a three-part numeric tag matching the script and `VERSION`.
Confirm that the tag selects the reviewed commit, use the explicit `refs/tags/<tag>` namespace, and avoid a same-named branch.

The unchanged workflow validates the tagged revision, packages the ZIP and sidecar, and runs `gh release create` with `--verify-tag` and `--prerelease`. It requires the remote tag to exist and marks the result as a prerelease candidate, not a final regular release. These flags are documented in the [GitHub CLI release reference](https://cli.github.com/manual/gh_release_create).

CI remains separate: `.github/workflows/ci.yml` has read-only contents permission, validates tags, and does not publish releases. Only the release workflow has `contents: write`.

### Stage 2: verify and approve promotion

1. Confirm the candidate's tag, commit, release notes, and successful workflow result.
2. Download `ConfigMgr-OSD-CopyOSDLogToFileShare-v1.0.0.zip` and its `.zip.sha256` sidecar from that candidate. Verify the downloaded ZIP's SHA-256, then extract it outside the source tree and validate its embedded manifest and source. A local pre-upload check alone is insufficient.
3. Resolve any asset or source-integrity failure before promotion. A workflow pass does not replace verification of the downloaded files. Do not relabel an unverified candidate as regular/latest.
4. After explicit approval, the authorized `vartaxe` maintainer updates the **same release ID** through the repository's [Update a release API](https://docs.github.com/en/rest/releases/releases#update-a-release), setting `prerelease` to `false` and `make_latest` to `"true"`. Promotion changes release metadata, not the tag, version, ZIP, or sidecar.
5. Read the release and latest-release metadata back, confirm v1.0.0 is non-draft, non-prerelease, and latest, and confirm the verified asset identities are unchanged before announcing the regular release.

Use only the already-authorized repository identity and permissions. If authorization or verification is insufficient, stop; do not broaden access or switch accounts to bypass the approval boundary.
Neither candidate publication nor promotion claims live ConfigMgr, WinPE, or SMB validation.

## Preserve published artifacts

Treat published tags, ZIPs, and sidecars as immutable. Do not move tags, replace assets, or reuse a version for changed bytes. Use a new version for changed release content.
Documentation on `main` may evolve without modifying earlier downloads. A correction to a release description must not imply that its existing assets or validation evidence changed.

The maintainer explicitly authorized the **2026-09-21 v1.0.0 baseline reset**.
That reset is disclosed in the release notes and distribution guide; earlier
downloads with the same label may differ. It is not permission to silently replace
future release bytes. Verify the current archive hash and advance the version for
later changes.

## Checksum checkout convention

`CHECKSUMS.txt` hashes the **checked-out file bytes** of every maintained file, including dotfiles, excluding only root `.git` metadata and the manifest itself.
Follow `.gitattributes`: PowerShell `.ps1` files use **CRLF**; other text files use **LF**, including Markdown, YAML, SVG, `LICENSE`, and `VERSION`. Maintained text is UTF-8 without a BOM. These rules avoid dependence on a contributor's global `core.autocrlf` setting.

Regenerate hashes after any content or line-ending change. Each manifest line contains a SHA-256 hash, exactly two spaces, and a root-relative path using `/`. Preserve deterministic hash-then-path sorting and write the manifest as UTF-8 without a BOM, with LF line endings and a final newline.

After normalizing text, run this recipe from the repository root in Windows PowerShell 5.1:

```powershell
$Root = (Get-Location).Path
$Files = @(Get-ChildItem -LiteralPath $Root -Force |
    Where-Object { $_.Name -ne '.git' } |
    ForEach-Object {
        if ($_.PSIsContainer) {
            Get-ChildItem -LiteralPath $_.FullName -File -Recurse -Force
        }
        else {
            $_
        }
    })
$Entries = @($Files | ForEach-Object {
    $RelativePath = $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
    if ($RelativePath -ne 'CHECKSUMS.txt') {
        '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $RelativePath
    }
})
$Utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText(
    (Join-Path $Root 'CHECKSUMS.txt'),
    (($Entries | Sort-Object) -join "`n") + "`n",
    $Utf8)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Validation.ps1 -Tag v1.0.0
```

This inventory includes ignored files too. Do not generate site output, test fixtures, or release archives in the source root. `-SkipChecksums` skips only the final manifest phase; repository checksum tests still run and are required for complete validation.
