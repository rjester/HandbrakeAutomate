. 'c:\SourceCode\AutomateHandbrake\src\Config.ps1'
$cfgfile = "$PSScriptRoot\..\src\config.json"
$cfg = Get-DefaultConfig -ConfigFile $cfgfile -SaveDetected
Write-Host "Saved config to: $cfgfile"
Write-Host "Contents:"; Get-Content $cfgfile -Raw
