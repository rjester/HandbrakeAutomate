. '$PSScriptRoot\..\src\Config.ps1'
$cfg = Get-DefaultConfig -ConfigFile "$PSScriptRoot\..\src\config.json"
$cfg | ConvertTo-Json -Depth 5
Write-Host "---done---"