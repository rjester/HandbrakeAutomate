<#
Invoke-MakeMKV.ps1
MakeMKV wrapper functions for detecting drives, listing titles, and ripping selected titles with progress.
Functions:
- Invoke-MakeMKV-FindDrives
- Invoke-MakeMKV-ListTitles
- Invoke-MakeMKV-RipTitles

All functions expect `makemkvcon` available on PATH or passed explicitly.
#>

function Invoke-MakeMKV-FindDrives {
    [CmdletBinding()]
    param(
        [string]$MakeMKVPath = 'makemkvcon'
    )
    $outFile = [IO.Path]::Combine($env:TEMP, "makemkv_info_$(Get-Random).log")
    & "$MakeMKVPath" -r --cache=1 info disc:9999 *> $outFile 2>&1
    $lines = Get-Content $outFile -ErrorAction SilentlyContinue
    Remove-Item $outFile -ErrorAction SilentlyContinue

    $drives = @()
    foreach ($line in $lines) {
        if ($line -match '^DRV:(\d+),(\d+),(\d+),(\d+),"([^"]*)","([^"]*)","([^"]*)"') {
            $index = [int]$Matches[1]
            $visible = [int]$Matches[2]
            $enabled = [int]$Matches[3]
            $flags = [int]$Matches[4]
            $driveName = $Matches[5]
            $discName = $Matches[6]
            $path = $Matches[7]
            $type = switch ($flags) { 1 {'DVD'} 12 {'Blu-ray'} 28 {'Blu-ray'} default {'Unknown'} }

            $drives += [PSCustomObject]@{
                Index = $index
                Visible = $visible
                Enabled = $enabled
                Type = $type
                DriveName = $driveName
                DiscName = $discName
                Path = $path
                Flags = $flags
            }
        }
    }
    return $drives | Where-Object { $_.Visible -ne 0 -and $_.Enabled -ne 0 }
}

function Invoke-MakeMKV-ListTitles {
    [CmdletBinding()]
    param(
        [int]$DriveIndex = 0,
        [string]$MakeMKVPath = 'makemkvcon'
    )
    $outFile = [IO.Path]::Combine($env:TEMP, "makemkv_titles_$(Get-Random).log")
    & "$MakeMKVPath" -r info disc:$DriveIndex *> $outFile 2>&1
    $lines = Get-Content $outFile -ErrorAction SilentlyContinue
    Remove-Item $outFile -ErrorAction SilentlyContinue

    $titles = @{}
    foreach ($line in $lines) {
        if ($line -match '^TINFO:(\d+),(\d+),\d?,"([^"]*)"') {
            $tidx = [int]$Matches[1]
            $attr = [int]$Matches[2]
            $val = $Matches[3]
            if (-not $titles.ContainsKey($tidx)) {
                $titles[$tidx] = [ordered]@{ Index = $tidx; Name = ''; Duration = ''; Chapters = 0; Size = ''; FileName = '' }
            }
            switch ($attr) {
                2  { $titles[$tidx].Name = $val }
                8  { $titles[$tidx].Chapters = $val }
                9  { $titles[$tidx].Duration = $val }
                10 { $titles[$tidx].Size = $val }
                27 { $titles[$tidx].FileName = $val }
            }
        }
    }
    return $titles.Values | Sort-Object Index
}

function Invoke-MakeMKV-RipTitles {
    [CmdletBinding()]
    param(
        [int]$DriveIndex = 0,
        [string]$Selection = 'all',
        [string]$OutDir,
        [string]$MakeMKVPath = 'makemkvcon',
        [int]$PollMs = 500
    )
    if (-not $OutDir) { throw 'OutDir is required' }
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

    Write-Host "Starting MakeMKV rip process..." -ForegroundColor Cyan
    Write-Host "  Drive: $DriveIndex" -ForegroundColor Gray
    Write-Host "  Selection: $Selection" -ForegroundColor Gray
    Write-Host "  Output: $OutDir" -ForegroundColor Gray

    $logFile = [IO.Path]::Combine($OutDir, "makemkv_rip_$(Get-Random).log")
    $args = @('-r','mkv',"disc:$DriveIndex", $Selection, """$OutDir""")

    $proc = Start-Process -FilePath $MakeMKVPath -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput $logFile -RedirectStandardError $logFile

    $lastPercent = -1
    $lastMilestone = -1
    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds $PollMs
        try {
            $tail = Get-Content $logFile -Tail 50 -ErrorAction SilentlyContinue
            foreach ($line in $tail) {
                if ($line -match '^PRGV:(\d+),(\d+),(\d+)') {
                    $current = [int]$Matches[1]
                    $max = [int]$Matches[3]
                    if ($max -gt 0) { $pct = [math]::Round(($current / $max) * 100,1) } else { $pct = 0 }
                    if ($pct -ne $lastPercent) { 
                        $lastPercent = $pct
                        Write-Progress -Activity 'MakeMKV Rip' -Status "$pct% complete" -PercentComplete $pct
                        # Report milestones
                        if ($pct -ge 25 -and $lastMilestone -lt 25) {
                            Write-Host "  → Progress: 25%" -ForegroundColor Gray
                            $lastMilestone = 25
                        } elseif ($pct -ge 50 -and $lastMilestone -lt 50) {
                            Write-Host "  → Progress: 50%" -ForegroundColor Gray
                            $lastMilestone = 50
                        } elseif ($pct -ge 75 -and $lastMilestone -lt 75) {
                            Write-Host "  → Progress: 75%" -ForegroundColor Gray
                            $lastMilestone = 75
                        }
                    }
                }
            }
        } catch { }
    }

    Write-Progress -Activity 'MakeMKV Rip' -Completed

    $exit = $proc.ExitCode
    # ensure final log capture
    Start-Sleep -Milliseconds 200
    $all = Get-Content $logFile -ErrorAction SilentlyContinue | Out-String

    $mkvFiles = Get-ChildItem -Path $OutDir -Filter '*.mkv' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

    if ($exit -eq 0) {
        Write-Host "✓ MakeMKV rip completed successfully" -ForegroundColor Green
        Write-Host "  Files created: $($mkvFiles.Count)" -ForegroundColor Gray
    } else {
        Write-Host "✗ MakeMKV rip failed with exit code $exit" -ForegroundColor Red
    }

    return [PSCustomObject]@{ Success = ($exit -eq 0); ExitCode = $exit; Log = $logFile; Files = $mkvFiles; RawOutput = $all }
}

# Intentionally not exporting module members to allow dot-sourcing this script.
