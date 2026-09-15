BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    $script:ProductionScript = Get-Content (Join-Path $script:Root 'Scripts\Copy-OSDLogToFileShare.ps1') -Raw
    $script:Ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $script:ProductionScript, [ref]$null, [ref]$null)
}
Describe 'Repository contract' {
    It 'keeps one matching three-part numeric version in the script and manifest' {
        $VersionMatch = [regex]::Match($script:ProductionScript, '(?m)^\$script:Version\s*=\s*''(\d+\.\d+\.\d+)''\s*$')
        $VersionMatch.Success | Should -BeTrue
        $ManifestVersion = (Get-Content (Join-Path $script:Root 'VERSION') -Raw).Trim()
        $ManifestVersion | Should -Match '^\d+\.\d+\.\d+$'
        $VersionMatch.Groups[1].Value | Should -BeExactly $ManifestVersion
    }

    It 'requires Windows PowerShell 5.1 and has strict mode and explicit exit' {
        $script:ProductionScript | Should -Match '(?m)^#Requires -Version 5\.1'
        $script:ProductionScript | Should -Match 'Set-StrictMode'
        $script:Ast.EndBlock.Statements[-1].GetType().Name | Should -Be 'ExitStatementAst'
    }

    It 'uses the ConfigMgr Task Sequence environment and WinPE OSDisk selection' {
        $script:ProductionScript | Should -Match 'Microsoft\.SMS\.TSEnvironment'
        $script:ProductionScript | Should -Match "Value\('OSDisk'\)"
    }

    It 'writes CMTrace format and uses every documented compatibility parameter' {
        $script:ProductionScript | Should -Match '<!\[LOG\['
        foreach ($Parameter in 'AllowUnencryptedSmb', 'AllowUnverifiedSmb', 'MinimumSmbDialect', 'AllowNtlmV2') {
            ([regex]::Matches($script:ProductionScript, $Parameter)).Count | Should -BeGreaterThan 1
        }
    }

    Describe 'Script header and help contract' -ForEach @(
        @{
            RelativePath = 'Scripts\Copy-OSDLogToFileShare.ps1'
            Synopsis     = 'Collects focused ConfigMgr OSD logs, creates a ZIP archive, and uploads it to an authenticated file share.'
            ExampleCount = 2
        },
        @{
            RelativePath = 'build\Invoke-Validation.ps1'
            Synopsis     = 'Validates the source tree using Windows PowerShell 5.1.'
            ExampleCount = 0
        }
    ) {
        BeforeAll {
            Set-StrictMode -Version 2.0
            $script:HeaderPath = Join-Path $script:Root $RelativePath
            $script:HeaderLines = [IO.File]::ReadAllLines($script:HeaderPath)
            $script:HeaderAst = [Management.Automation.Language.Parser]::ParseFile(
                $script:HeaderPath, [ref]$null, [ref]$null)
            $script:HeaderParameterNames = @($script:HeaderAst.ParamBlock.Parameters |
                    ForEach-Object { $_.Name.VariablePath.UserPath } | Sort-Object)
        }

        It 'keeps the minimum-version declaration first and separate from help in <RelativePath>' {
            $script:HeaderLines[0] | Should -BeExactly '#Requires -Version 5.1'
            $script:HeaderLines[1] | Should -BeExactly ''
            $script:HeaderLines[2] | Should -BeExactly '<#'
            $script:HeaderAst.ScriptRequirements.RequiredPSVersion | Should -Be ([version]'5.1')
        }

        It 'associates the authored synopsis and parameter help with <RelativePath>' {
            $CommentHelp = $script:HeaderAst.GetHelpContent()
            $CommentHelp | Should -Not -BeNullOrEmpty
            $CommentHelp.Synopsis.Trim() | Should -BeExactly $Synopsis
            $HelpNames = @($CommentHelp.Parameters.Keys | Sort-Object)
            @(Compare-Object $script:HeaderParameterNames $HelpNames).Count | Should -Be 0
        }

        It 'exposes full help and examples without executing <RelativePath>' {
            $Help = Get-Help -Name $script:HeaderPath -Full -ErrorAction Stop
            $Help.Synopsis.Trim() | Should -BeExactly $Synopsis
            $HelpNames = @($Help.Parameters.Parameter.Name | Sort-Object)
            @(Compare-Object $script:HeaderParameterNames $HelpNames).Count | Should -Be 0
            $Examples = @()
            if ($null -ne $Help.PSObject.Properties['Examples']) {
                $Examples = @($Help.Examples.Example | Where-Object { $_.Code })
            }
            $Examples.Count | Should -Be $ExampleCount
        }
    }

    It 'avoids prohibited patterns' {
        $script:ProductionScript | Should -Not -Match 'cmdkey|net\s+use|Win32_Product|Get-WmiObject|\bwmic(?:\.exe)?\b'
    }

    It 'binds the script-scoped credential in the orchestration and leaves no unqualified Credential reference' {
        $Statements = $script:Ast.EndBlock.Statements
        $Start = ($Statements | Where-Object { $_.Extent.Text -eq '$ExitCode = 1' } | Select-Object -First 1).Extent.StartOffset
        $End = ($Statements | Where-Object { $_ -is [System.Management.Automation.Language.ExitStatementAst] } | Select-Object -Last 1).Extent.EndOffset
        $Orchestration = [System.Management.Automation.Language.Parser]::ParseInput(
            $script:Ast.Extent.Text.Substring($Start, $End - $Start), [ref]$null, [ref]$null)

        $Unqualified = @($Orchestration.FindAll({
                    param($Node)
                    $Node -is [System.Management.Automation.Language.VariableExpressionAst] -and
                    $Node.VariablePath.UserPath -ieq 'Credential'
                }, $true))
        $Unqualified.Count | Should -Be 0

        $SendArchive = @($Orchestration.FindAll({
                    param($Node)
                    $Node -is [System.Management.Automation.Language.CommandAst] -and
                    $Node.GetCommandName() -ieq 'Send-Archive'
                }, $true))
        $SendArchive.Count | Should -Be 1
        $SendArchive[0].Extent.Text | Should -Match '-Credential\s+\$script:Credential\b'
    }

    It 'has one matching SHA-256 entry for every maintained file except the checksum manifest' {
        $Names = @()
        foreach ($Line in Get-Content -LiteralPath (Join-Path $script:Root 'CHECKSUMS.txt')) {
            $Entry = [regex]::Match($Line, '^([A-Fa-f0-9]{64})  ([^\\]+)$')
            $Entry.Success | Should -BeTrue
            $Name = $Entry.Groups[2].Value
            $Name | Should -Not -Be 'CHECKSUMS.txt'
            $Path = Join-Path $script:Root $Name.Replace('/', '\')
            Test-Path -LiteralPath $Path -PathType Leaf | Should -BeTrue
            (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash | Should -Be $Entry.Groups[1].Value
            $Names += $Name
        }
        @($Names | Sort-Object -Unique).Count | Should -Be $Names.Count
        $Expected = @(
            Get-ChildItem -LiteralPath $script:Root -Recurse -File -Force |
                Where-Object { $_.Name -notin @('.git', 'CHECKSUMS.txt') -and $_.FullName -notlike "$script:Root\.git\*" } |
                ForEach-Object { $_.FullName.Substring($script:Root.Length + 1).Replace('\', '/') }
        )
        @(Compare-Object ($Expected | Sort-Object) ($Names | Sort-Object)).Count | Should -Be 0
    }

    It 'pins checkout actions, retains publisher verification, and preserves release gates' {
        $ExpectedCheckoutReference = 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1'
        $WorkflowFiles = @(Get-ChildItem -LiteralPath (Join-Path $script:Root '.github\workflows') -Filter '*.yml' -File)
        $WorkflowFiles.Count | Should -BeGreaterThan 0

        foreach ($WorkflowFile in $WorkflowFiles) {
            $WorkflowContent = Get-Content -LiteralPath $WorkflowFile.FullName -Raw
            $WorkflowContent | Should -Match ('(?m)^\s*-\s*uses:\s+' + [regex]::Escape($ExpectedCheckoutReference) + '\s*$')
            $WorkflowContent | Should -Not -Match '(?i)-SkipPublisherCheck'
        }

        $CiWorkflow = Get-Content -LiteralPath (Join-Path $script:Root '.github\workflows\ci.yml') -Raw
        $CiWorkflow | Should -Match '\$ValidationParameters\s*=\s*@\{\}'

        $ReleaseWorkflow = Get-Content -LiteralPath (Join-Path $script:Root '.github\workflows\release.yml') -Raw
        $ReleaseWorkflow | Should -Match "(?m)^\s*-\s*'v\*\.\*\.\*'\s*$"
        $ReleaseWorkflow | Should -Match '(?m)^\s+ref:\s+refs/tags/\$\{\{\s*env\.RELEASE_TAG\s*\}\}\s*$'
        $ReleaseWorkflow | Should -Match '(?m)^\s+git archive[^\r\n]+"refs/tags/\$env:RELEASE_TAG"\s*$'
        foreach ($RequiredText in 'Validate tagged revision', 'Create release archive', 'Get-FileHash', 'Publish GitHub prerelease', 'gh release create', '--verify-tag') {
            $ReleaseWorkflow | Should -Match ([regex]::Escape($RequiredText))
        }

        $ValidationDocumentation = Get-Content -LiteralPath (Join-Path $script:Root 'docs\validation.md') -Raw
        $ValidationDocumentation | Should -Not -Match '(?i)-SkipPublisherCheck'
        $ValidationDocumentation | Should -Match '(?i)do not bypass publisher verification'
    }
}

Describe 'Static illustration contract' {
    It 'gives every SVG an explicit viewport and linked accessible title and description' {
        $Assets = @(Get-ChildItem -LiteralPath (Join-Path $script:Root 'assets') -Filter '*.svg' -File)
        $Assets.Count | Should -BeGreaterThan 0
        foreach ($Asset in $Assets) {
            $Document = New-Object Xml.XmlDocument
            $Document.XmlResolver = $null
            $Document.Load($Asset.FullName)
            $Svg = $Document.DocumentElement
            $Svg.LocalName | Should -BeExactly 'svg'
            $Svg.GetAttribute('role') | Should -BeExactly 'img'
            @($Svg.GetAttribute('viewBox') -split '\s+').Count | Should -Be 4
            [int]$Svg.GetAttribute('width') | Should -BeGreaterThan 0
            [int]$Svg.GetAttribute('height') | Should -BeGreaterThan 0

            $Labels = @($Svg.GetAttribute('aria-labelledby') -split '\s+')
            $Labels.Count | Should -Be 2
            foreach ($Id in $Labels) {
                $Elements = @($Svg.SelectNodes('//*[@id]') | Where-Object { $_.GetAttribute('id') -ceq $Id })
                $Elements.Count | Should -Be 1
                $Elements[0].InnerText | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'preserves every numbered step and description in both compact workflow variants' {
        foreach ($Pair in @(
                @{ Name = 'copylog-flow'; Count = 7 },
                @{ Name = 'task-sequence-flow'; Count = 4 }
            )) {
            $Wide = New-Object Xml.XmlDocument
            $Wide.XmlResolver = $null
            $Wide.Load((Join-Path $script:Root "assets\$($Pair.Name).svg"))
            $Compact = New-Object Xml.XmlDocument
            $Compact.XmlResolver = $null
            $Compact.Load((Join-Path $script:Root "assets\$($Pair.Name)-compact.svg"))
            $WideSteps = @($Wide.GetElementsByTagName('text') |
                    Where-Object { ($_.GetAttribute('class') -split '\s+') -contains 'number' } |
                    ForEach-Object { $_.InnerText })
            $CompactSteps = @($Compact.GetElementsByTagName('text') |
                    Where-Object { ($_.GetAttribute('class') -split '\s+') -contains 'number' } |
                    ForEach-Object { $_.InnerText })
            ($WideSteps -join ',') | Should -BeExactly ((1..$Pair.Count) -join ',')
            ($CompactSteps -join ',') | Should -BeExactly ($WideSteps -join ',')
            $Compact.GetElementsByTagName('title')[0].InnerText |
                Should -BeExactly $Wide.GetElementsByTagName('title')[0].InnerText
            $Compact.GetElementsByTagName('desc')[0].InnerText |
                Should -BeExactly $Wide.GetElementsByTagName('desc')[0].InnerText
        }
    }
}
