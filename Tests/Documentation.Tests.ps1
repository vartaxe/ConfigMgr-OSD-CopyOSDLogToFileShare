BeforeAll {
    $script:DocumentationRoot = Split-Path -Parent $PSScriptRoot
    $script:ReleaseTag = 'v' + (Get-Content -LiteralPath (Join-Path $script:DocumentationRoot 'VERSION') -Raw).Trim()
    $script:SiteConfiguration = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot '_config.yml') -Raw
    $script:DocumentationFiles = @(Get-ChildItem -LiteralPath $script:DocumentationRoot -Filter '*.md' -File)
    foreach ($Folder in 'docs', 'examples') {
        $script:DocumentationFiles += @(Get-ChildItem -LiteralPath (Join-Path $script:DocumentationRoot $Folder) -Filter '*.md' -File)
    }
}

Describe 'Documentation and Pages contract' {
    It 'resolves every local inline Markdown link and HTML image to an existing source file' {
        $Checked = 0
        foreach ($File in $script:DocumentationFiles) {
            $Content = Get-Content -LiteralPath $File.FullName -Raw
            $Links = [regex]::Matches($Content, '\]\((?<Target>[^\s)]+)\)|(?:src|srcset)="(?<Target>[^"]+)"')
            foreach ($Link in $Links) {
                $Target = $Link.Groups['Target'].Value
                if ($Target -match '^(?:https?://|mailto:|#)') {
                    continue
                }
                $SourcePath = ($Target -split '[?#]', 2)[0]
                $Resolved = [IO.Path]::GetFullPath((Join-Path $File.DirectoryName $SourcePath.Replace('/', '\')))
                $Resolved.StartsWith($script:DocumentationRoot + '\', [StringComparison]::OrdinalIgnoreCase) |
                    Should -BeTrue -Because "$($File.Name) must link within this source tree: $Target"
                Test-Path -LiteralPath $Resolved -PathType Leaf |
                    Should -BeTrue -Because "$($File.Name) links to $Target"
                $Checked++
            }
        }
        $Checked | Should -BeGreaterThan 100
    }

    It 'resolves local Markdown heading anchors used by the guides' {
        $Checked = 0
        foreach ($File in $script:DocumentationFiles) {
            $Content = Get-Content -LiteralPath $File.FullName -Raw
            foreach ($Link in [regex]::Matches($Content, '\]\((?<Path>[^)\s#]*)#(?<Anchor>[^)\s]+)\)')) {
                $SourcePath = $Link.Groups['Path'].Value
                if ($SourcePath -match '^https?://') {
                    continue
                }
                $Resolved = $File.FullName
                if ($SourcePath) {
                    $Resolved = Join-Path $File.DirectoryName $SourcePath.Replace('/', '\')
                }
                $Headings = [regex]::Matches((Get-Content -LiteralPath $Resolved -Raw), '(?m)^#{1,6}\s+(.+?)\s*$')
                $Anchors = @($Headings | ForEach-Object {
                        ($_.Groups[1].Value.ToLowerInvariant() -replace '[^a-z0-9 _-]', '') -replace ' ', '-'
                    })
                $Anchors | Should -Contain $Link.Groups['Anchor'].Value -Because "$($File.Name) has a heading link to $($Link.Value)"
                $Checked++
            }
        }
        $Checked | Should -BeGreaterThan 5
    }

    It 'keeps the project base path and required branch-based Pages plugins' {
        foreach ($Setting in @(
                'theme: jekyll-theme-cayman',
                'url: https://vartaxe.github.io',
                'baseurl: /ConfigMgr-OSD-CopyOSDLogToFileShare',
                'repository: vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare',
                'lang: en', 'author: Claudio Mendes', 'show_downloads: false',
                '  - jekyll-relative-links', '  - jekyll-optional-front-matter', '  - jekyll-seo-tag'
            )) {
            $script:SiteConfiguration | Should -Match ('(?m)^' + [regex]::Escape($Setting) + '\r?$')
        }
        $script:SiteConfiguration | Should -Match 'relative_links:\s+enabled: true'
        $script:SiteConfiguration | Should -Match 'layout: default'
        $script:SiteConfiguration | Should -Match 'url: /docs/deployment\.html'
        $script:SiteConfiguration | Should -Not -Match '(?m)^\s+url:.*\.md(?:[#?\s]|$)'
        foreach ($Resource in 'Scripts', 'assets', 'LICENSE', 'docs', 'examples') {
            $Exclusions = ($script:SiteConfiguration -split '(?m)^exclude:\s*\r?\n', 2)[1]
            $Exclusions | Should -Not -Match ('(?m)^\s+-\s+' + [regex]::Escape($Resource) + '\s*$')
        }
    }

    It 'keeps a focused landing page and a stable examples permalink' {
        $Landing = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot 'index.md') -Raw
        $Landing | Should -Not -Match '\{%\s*include'
        foreach ($Target in 'docs/deployment.md', 'docs/compatibility.md', 'SECURITY.md',
            'docs/logging.md', 'docs/troubleshooting.md', 'docs/validation.md',
            'Scripts/Copy-OSDLogToFileShare.ps1', 'LICENSE', "releases/tag/$script:ReleaseTag") {
            $Landing | Should -Match ([regex]::Escape($Target))
        }
        $Examples = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot 'examples\README.md') -Raw
        $Examples | Should -Match '(?m)^permalink: /examples/\r?$'
    }

    It 'gives every guide a title and source-relative documentation home link' {
        foreach ($File in $script:DocumentationFiles | Where-Object { $_.DirectoryName -ne $script:DocumentationRoot }) {
            $Content = Get-Content -LiteralPath $File.FullName -Raw
            $Content | Should -Match '\A---\r?\ntitle: .+\r?\n' -Because $File.Name
            $Content | Should -Match '\[Documentation home\]\(\.\./index\.md\)' -Because $File.Name
        }
    }

    It 'keeps static resources baseurl-aware and the skip link connected to main content' {
        $Layout = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot '_layouts\default.html') -Raw
        $Layout | Should -Match 'href="#main-content"'
        $Layout | Should -Match '<main id="main-content"[^>]*tabindex="-1"'
        $Layout | Should -Match "'/assets/favicon.svg'\s*\|\s*relative_url"
        $Layout | Should -Match "'/assets/css/style.css\?v='\s*\|\s*append:\s*site.github.build_revision\s*\|\s*relative_url"
        $Layout | Should -Not -Match '(?:href|src)="[^"]*\.md(?:[#?"]|$)'
    }

    It 'makes generated code and table scroll regions keyboard-focusable with visible focus rings' {
        $Layout = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot '_layouts\default.html') -Raw
        foreach ($Element in '<pre class="highlight">', '<pre>', '<table>') {
            $Focusable = $Element.Replace('>', ' tabindex="0">')
            $Layout | Should -Match ([regex]::Escape("| replace: '$Element', '$Focusable'"))
        }
        $Styles = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot 'assets\css\style.scss') -Raw
        foreach ($Element in 'pre', 'table') {
            $Styles | Should -Match ('(?s)\.main-content ' + $Element + ':focus-visible[^{]*\{[^}]*outline:\s*3px solid var\(--focus\)')
            $Styles | Should -Match ('(?s)\.main-content ' + $Element + '\s*\{[^}]*overflow-x:\s*auto')
        }
    }

    It 'overrides inherited Cayman code colors and supplies a readable syntax fallback' {
        $Styles = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot 'assets\css\style.scss') -Raw
        $Styles | Should -Match '(?s)\.main-content pre code\s*\{\s*color:\s*inherit;\s*background:\s*transparent;'
        $Styles | Should -Match '(?s)\.main-content \.highlight span\s*\{\s*color:\s*var\(--ink\);\s*background-color:\s*transparent;'
        foreach ($Rule in @(
                @{ Selector = '.main-content .highlight .c1'; Color = 'muted' },
                @{ Selector = '.main-content .highlight [class^="k"]'; Color = 'link' },
                @{ Selector = '.main-content .highlight [class^="s"]'; Color = 'accent' }
            )) {
            $Styles | Should -Match ('(?s)' + [regex]::Escape($Rule.Selector) +
                '[^{]*\{\s*color:\s*var\(--' + $Rule.Color + '\);')
        }
    }

    It 'keeps all code palette colors above normal-text contrast in both themes' {
        $Styles = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot 'assets\css\style.scss') -Raw
        $Themes = [regex]::Matches($Styles, '(?s):root\s*\{([^}]+)\}')
        $Themes.Count | Should -Be 2
        foreach ($Theme in $Themes) {
            $Luminance = @{}
            foreach ($Variable in [regex]::Matches($Theme.Groups[1].Value, '--(panel|ink|muted|link|accent):\s*#([a-fA-F0-9]{6});')) {
                $Hex = $Variable.Groups[2].Value
                $Channels = @(foreach ($Offset in 0, 2, 4) {
                        $Channel = [Convert]::ToInt32($Hex.Substring($Offset, 2), 16) / 255.0
                        if ($Channel -le 0.04045) { $Channel / 12.92 }
                        else { [Math]::Pow(($Channel + 0.055) / 1.055, 2.4) }
                    })
                $Luminance[$Variable.Groups[1].Value] = 0.2126 * $Channels[0] + 0.7152 * $Channels[1] + 0.0722 * $Channels[2]
            }
            $Luminance.Count | Should -Be 5
            foreach ($Color in 'ink', 'muted', 'link', 'accent') {
                $Ratio = ([Math]::Max($Luminance[$Color], $Luminance.panel) + 0.05) /
                    ([Math]::Min($Luminance[$Color], $Luminance.panel) + 0.05)
                $Ratio | Should -BeGreaterOrEqual 4.5 -Because "$Color must be readable on the code panel"
            }
        }
    }

    It 'keeps responsive picture sizes fluid and accessible labels equivalent' {
        foreach ($File in $script:DocumentationFiles) {
            $Content = Get-Content -LiteralPath $File.FullName -Raw
            $Pictures = [regex]::Matches($Content, '(?s)<picture\b.*?</picture>')
            foreach ($Image in [regex]::Matches($Content, '<(?:img|source)\s[^>]+>')) {
                $Image.Value | Should -Match '\bwidth="[1-9]\d*"'
                $InPicture = @($Pictures | Where-Object {
                        $_.Index -le $Image.Index -and $Image.Index -lt ($_.Index + $_.Length)
                    }).Count -gt 0
                if ($InPicture) {
                    $Image.Value | Should -Not -Match '\bheight=' -Because 'GitHub keeps a fixed HTML height when it shrinks the width'
                }
                else {
                    $Image.Value | Should -Match '\bheight="[1-9]\d*"'
                }
                if ($Image.Value.StartsWith('<img ')) {
                    $Image.Value | Should -Match '\balt="[^"]*"'
                    if ($Image.Value -match '\balt=""') {
                        $Image.Value | Should -Match '\baria-hidden="true"'
                    }
                    else {
                        $Image.Value | Should -Not -Match '\baria-hidden="true"'
                    }
                }
            }
        }
        $Wide = [xml](Get-Content -LiteralPath (Join-Path $script:DocumentationRoot 'assets\banner.svg') -Raw)
        $Compact = [xml](Get-Content -LiteralPath (Join-Path $script:DocumentationRoot 'assets\banner-compact.svg') -Raw)
        $Compact.svg.title.InnerText | Should -BeExactly $Wide.svg.title.InnerText
        $Compact.svg.desc.InnerText | Should -BeExactly $Wide.svg.desc.InnerText
        $Readme = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot 'README.md') -Raw
        $Readme | Should -Match '<source media="\(max-width: 720px\)" srcset="assets/banner-compact\.svg\?v='
        $Readme | Should -Match ('RELEASE-' + [regex]::Escape($script:ReleaseTag) + '-155799')
        $Readme | Should -Match 'badge\.svg\?branch=main&event=push'
        $Readme | Should -Match 'Live ConfigMgr, WinPE, and SMB validation remains pending'
    }

    It 'keeps release summaries focused on the current version without obsolete artifact identities' {
        foreach ($Name in 'CHANGELOG.md', 'RELEASE-NOTES.md') {
            $Content = Get-Content -LiteralPath (Join-Path $script:DocumentationRoot $Name) -Raw
            $VersionHeadings = [regex]::Matches($Content, '(?m)^## (v\d+\.\d+\.\d+)\s*\r?$')
            $VersionHeadings.Count | Should -Be 1
            $VersionHeadings[0].Groups[1].Value | Should -BeExactly $script:ReleaseTag
            $Content | Should -Not -Match '(?i)reissue|actions/runs/|\b[0-9a-f]{40,64}\b'
        }
    }
}
