BeforeAll{
 $script:Root=Split-Path -Parent $PSScriptRoot
 $script:ProductionScript=Get-Content (Join-Path $script:Root 'Scripts\Copy-OSDLogToFileShare.ps1') -Raw
}
Describe 'Repository contract'{
 It 'uses one matching three-part numeric version in the script and manifest'{
  $VersionMatch=[regex]::Match($script:ProductionScript,'(?m)^\$script:Version\s*=\s*''(\d+\.\d+\.\d+)''\s*$')
  $VersionMatch.Success|Should -BeTrue
  $ManifestVersion=(Get-Content (Join-Path $script:Root 'VERSION') -Raw).Trim()
  $ManifestVersion|Should -Match '^\d+\.\d+\.\d+$'
  $VersionMatch.Groups[1].Value|Should -BeExactly $ManifestVersion
 }
 It 'uses ConfigMgr TS environment'{$script:ProductionScript|Should -Match 'Microsoft\.SMS\.TSEnvironment'}
 It 'writes CMTrace format'{$script:ProductionScript|Should -Match '<!\[LOG\['}
 It 'uses OSDisk when WinPE identifies the operating system volume'{$script:ProductionScript|Should -Match "Value\('OSDisk'\)"}
 It 'uses every documented compatibility parameter'{
  foreach($p in 'AllowUnencryptedSmb','AllowUnverifiedSmb','MinimumSmbDialect','AllowNtlmV2'){
   ([regex]::Matches($script:ProductionScript,$p)).Count|Should -BeGreaterThan 1
  }
 }
 It 'avoids prohibited patterns'{$script:ProductionScript|Should -Not -Match 'cmdkey|net\s+use|Win32_Product|Get-WmiObject|\bwmic(?:\.exe)?\b'}
}
