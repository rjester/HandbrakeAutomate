$files = @(
    'c:\SourceCode\AutomateHandbrake\src\Invoke-DvdRip.ps1',
    'c:\SourceCode\AutomateHandbrake\src\Invoke-MakeMKV.ps1',
    'c:\SourceCode\AutomateHandbrake\src\Invoke-HandBrakeEncode.ps1',
    'c:\SourceCode\AutomateHandbrake\src\Config.ps1',
    'c:\SourceCode\AutomateHandbrake\src\Logger.ps1'
)
$ok = $true
foreach ($f in $files) {
    Write-Host "Checking $f"
    $tokens = [ref]$null
    $errors = [ref]$null
    try {
        [void][System.Management.Automation.Language.Parser]::ParseFile($f, $tokens, $errors)
    } catch {
        Write-Host ("Parse exception for {0}: {1}" -f $f, $_) -ForegroundColor Red
        $ok = $false
        continue
    }
    if ($errors.Value) {
        Write-Host ("ERRORS in {0}:" -f $f) -ForegroundColor Red
        $errors.Value | ForEach-Object { Write-Host $_.ToString() }
        $ok = $false
    } else {
        Write-Host "OK: $f" -ForegroundColor Green
    }
}
if (-not $ok) { exit 1 } else { exit 0 }
