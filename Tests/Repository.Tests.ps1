BeforeAll{$script:ProductionScript=Get-Content (Join-Path $PSScriptRoot '..\Scripts\Copy-OSDLogToFileShare.ps1') -Raw}
Describe 'Repository contract'{
 It 'uses version 1.0.0'{$script:ProductionScript|Should -Match '\$script:Version\s*=\s*''1\.0\.0'''}
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
