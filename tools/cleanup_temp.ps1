$p = Join-Path $env:TEMP 'dvd_rip_temp'
if (-not (Test-Path $p)) { Write-Output "temp-not-found: $p"; exit 0 }
$files = Get-ChildItem -Path $p -Recurse -Filter '*.mkv' -File -ErrorAction SilentlyContinue
if (-not $files -or $files.Count -eq 0) { Write-Output "no-mkvs-found in $p"; exit 0 }
$count = $files.Count
foreach ($f in $files) {
    try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; Write-Output "deleted:$($f.FullName)" } catch { Write-Output "failed-to-delete:$($f.FullName): $($_.Exception.Message)" }
}
Start-Sleep -Milliseconds 200
$remaining = Get-ChildItem -Path $p -Recurse -Filter '*.mkv' -File -ErrorAction SilentlyContinue
$remainingCount = if ($remaining) { $remaining.Count } else { 0 }
Write-Output "deleted-count:$count; remaining:$remainingCount"
