<#
Invoke-DvdRip.ps1
Orchestrator for single-disc DVD rip using MakeMKV (makemkvcon) and HandBrakeCLI.
Features:
- Auto-detect MakeMKV/HandBrake executables
- Detect optical drive with disc (single-disc)
- Interactive title selection (indices or 'all')
- Rip selected titles to temp folder (MakeMKV)
- Encode MKV -> MP4/MKV (HandBrakeCLI) using custom JSON preset and preset name
- Delete temp MKV files after successful encode (unless -KeepTemp)

Usage example:
pwsh c:\SourceCode\AutomateHandbrake\src\Invoke-DvdRip.ps1 -OutputPath "C:\Videos" -PresetFile "C:\Presets\My.json" -PresetName "MyPreset" -OutputFormat mp4
#>
[CmdletBinding()]
param(
    [string]$PresetFile = "$env:USERPROFILE\AppData\Roaming\HandBrake\presets.json",
    [string]$PresetName = "Fast 1080p30",
    [string]$OutputPath = "$PWD\output",
    [string]$TempPath = "$env:TEMP\dvd_rip_temp",
    [ValidateSet('mp4','mkv')] [string]$OutputFormat = 'mp4',
    [string]$MakeMKVPath,
    [string]$HandBrakePath,
    [switch]$KeepTemp,
    [switch]$VerboseLogs
)

# Load config and logger modules from script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$ScriptDir\Config.ps1"
. "$ScriptDir\Logger.ps1"

# Initialize logger
Initialize-Logger -LogDir (Join-Path $ScriptDir 'logs') | Out-Null

# Load or detect config; on first run save detected tool paths
$configFile = Join-Path $ScriptDir 'config.json'
if (-not (Test-Path $configFile)) {
    Write-Log "Config not found; detecting tool paths and saving to $configFile" -Level INFO
    $cfg = Get-DefaultConfig -ConfigFile $configFile -SaveDetected
} else {
    $cfg = Get-DefaultConfig -ConfigFile $configFile
}

# Apply defaults from config when parameters not explicitly provided
if (-not $PSBoundParameters.ContainsKey('PresetFile') -or -not $PresetFile) { $PresetFile = $cfg.PresetFile }
if (-not $PSBoundParameters.ContainsKey('OutputPath') -or -not $OutputPath) { $OutputPath = $cfg.DefaultOutputPath }
if (-not $PSBoundParameters.ContainsKey('TempPath') -or -not $TempPath) { $TempPath = $cfg.DefaultTempPath }

# Persist explicit tool paths if provided
if ($PSBoundParameters.ContainsKey('MakeMKVPath') -and $MakeMKVPath) {
    $cfg.MakeMKVPath = $MakeMKVPath
    try { Save-Config -Config $cfg -ConfigFile $configFile | Out-Null; Write-Log "Saved MakeMKVPath to config: $MakeMKVPath" -Level INFO } catch { Write-Log "Failed to save MakeMKVPath: $_" -Level WARN }
}
if ($PSBoundParameters.ContainsKey('HandBrakePath') -and $HandBrakePath) {
    $cfg.HandBrakePath = $HandBrakePath
    try { Save-Config -Config $cfg -ConfigFile $configFile | Out-Null; Write-Log "Saved HandBrakePath to config: $HandBrakePath" -Level INFO } catch { Write-Log "Failed to save HandBrakePath: $_" -Level WARN }
}


function Find-Executable {
    param([string[]]$Names)
    foreach ($name in $Names) {
        # 1) Check PATH
        $which = (Get-Command $name -ErrorAction SilentlyContinue)?.Source
        if ($which) { return $which }

        # 2) Common Program Files locations (Windows)
        $candidates = @(
            "$env:ProgramFiles\\$name",
            "$env:ProgramFiles(x86)\\$name",
            "$env:ProgramFiles\\$name.exe",
            "$env:ProgramFiles(x86)\\$name.exe",
            "C:\\Program Files\\$name\\$name.exe",
            "C:\\Program Files (x86)\\$name\\$name.exe"
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { return $c }
        }
    }
    return $null
}

function Get-OpticalDriveWithDisc {
    param([string]$MakeMKVPath)
    if (-not $MakeMKVPath) { throw 'makemkvcon not found' }

    $outFile = [IO.Path]::Combine($env:TEMP, "makemkv_info_$(Get-Random).log")
    & "$MakeMKVPath" -r --cache=1 info disc:9999 *> $outFile 2>&1

    $lines = Get-Content $outFile -ErrorAction SilentlyContinue
    Remove-Item $outFile -ErrorAction SilentlyContinue

    foreach ($line in $lines) {
        if ($line -match '^DRV:(\d+),(\d+),(\d+),(\d+),"([^"]*)","([^"]*)","([^"]*)"') {
            $index = [int]$Matches[1]
            $visible = $Matches[2]
            $enabled = $Matches[3]
            $flags = [int]$Matches[4]
            $driveName = $Matches[5]
            $discName = $Matches[6]
            $path = $Matches[7]

            # flags: 1 = DVD, 12/28 = Blu-ray
            if ($visible -ne '0' -and $enabled -ne '0' -and ($flags -band 1)) {
                return [PSCustomObject]@{ Index = $index; DriveName = $driveName; DiscName = $discName; Path = $path }
            }
        }
    }
    return $null
}

function Get-DiscTitles {
    param([string]$MakeMKVPath, [int]$DriveIndex)
    $outFile = [IO.Path]::Combine($env:TEMP, "makemkv_titles_$(Get-Random).log")
    & "$MakeMKVPath" -r info disc:$DriveIndex *> $outFile 2>&1
    $lines = Get-Content $outFile -ErrorAction SilentlyContinue
    Remove-Item $outFile -ErrorAction SilentlyContinue

    $titles = @{}
    foreach ($line in $lines) {
        # TINFO:titleIdx,attrId,code,"value"
        if ($line -match '^TINFO:(\d+),(\d+),\d+,"([^"]*)"') {
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

function Prompt-SelectTitles {
    param([array]$Titles)
    Write-Host "Available titles:" -ForegroundColor Cyan
    foreach ($t in $Titles) {
        $name = if ($t.Name) { $t.Name } else { "Title $($t.Index)" }
        Write-Host "[$($t.Index)]: $($t.Duration) - $($t.Size) - $name"
    }
    while ($true) {
        $sel = Read-Host "Enter title number(s) to rip (comma-separated), or 'all'"
        if ($sel -eq 'all') { return 'all' }
        $parts = $sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        if (-not $parts) { Write-Host "Invalid selection" -ForegroundColor Yellow; continue }
        $valid = $true
        foreach ($p in $parts) {
            if (-not ($p -as [int])) { $valid = $false; break }
            $exists = $false
            if ($Titles | Where-Object { $_.Index -eq [int]$p }) { $exists = $true }
            if (-not $exists) { $valid = $false; break }
        }
        if ($valid) { return ($parts -join ',') }
        Write-Host "Invalid selection or index out of range" -ForegroundColor Yellow
    }
}

function Start-MakeMKV-Rip {
    param([string]$MakeMKVPath, [int]$DriveIndex, [string]$Selection, [string]$OutDir)
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    $log = [IO.Path]::Combine($OutDir, "makemkv_rip_$(Get-Random).log")

    Write-Host "  → Starting MakeMKV rip process..." -ForegroundColor Gray

    $args = @('-r', 'mkv', "disc:$DriveIndex", $Selection, "$OutDir")
    
    # Run MakeMKV with output redirected to log file
    $proc = Start-Process -FilePath $MakeMKVPath -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError $log

    $percent = 0
    $lastReportedPercent = -1
    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds 500
        try {
            $tail = Get-Content $log -Tail 50 -ErrorAction SilentlyContinue
            foreach ($line in $tail) {
                if ($line -match 'PRGV:(\d+),(\d+),(\d+)') {
                    $current = [int]$Matches[1]
                    $max = [int]$Matches[3]
                    if ($max -ne 0) { $new = [math]::Round(($current / $max) * 100, 1) } else { $new = 0 }
                    if ($new -ne $percent) { 
                        $percent = $new
                        Write-Progress -Activity 'MakeMKV Rip' -Status "$percent% complete" -PercentComplete $percent
                        # Report progress milestones
                        if ($percent -ge 25 -and $lastReportedPercent -lt 25) {
                            Write-Host "  → Progress: 25%" -ForegroundColor Gray
                            $lastReportedPercent = 25
                        } elseif ($percent -ge 50 -and $lastReportedPercent -lt 50) {
                            Write-Host "  → Progress: 50%" -ForegroundColor Gray
                            $lastReportedPercent = 50
                        } elseif ($percent -ge 75 -and $lastReportedPercent -lt 75) {
                            Write-Host "  → Progress: 75%" -ForegroundColor Gray
                            $lastReportedPercent = 75
                        }
                    }
                }
            }
        } catch {
            # Suppress errors during polling (file may be locked or not yet created)
        }
    }

    Write-Progress -Activity 'MakeMKV Rip' -Completed

    $exit = $proc.ExitCode

    return @{ Success = ($exit -eq 0); Log = $log }
}

function Start-HandBrake-Encode {
    param([string]$HandBrakePath, [string]$InputFile, [string]$OutputFile, [string]$PresetFile, [string]$PresetName, [string]$Format)
    $log = [IO.Path]::Combine((Split-Path $OutputFile), "handbrake_$(Split-Path $InputFile -Leaf)-$(Get-Random).log")
    
    Write-Host "  → Starting HandBrake encode process..." -ForegroundColor Gray
    
    $args = @()
    if ($PresetFile -and (Test-Path $PresetFile)) { $args += "--preset-import-file"; $args += "`"$PresetFile`"" }
    if ($PresetName) { $args += "-Z"; $args += "`"$PresetName`"" }
    $args += "-i"; $args += "`"$InputFile`""
    $args += "-o"; $args += "`"$OutputFile`""
    if ($Format -eq 'mp4') { $args += "-f"; $args += "av_mp4" } else { $args += "-f"; $args += "av_mkv" }
    $args += "--json"

    # Run HandBrakeCLI with progress monitoring - redirect output to log file
    $proc = Start-Process -FilePath $HandBrakePath -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError $log

    $lastReportedPercent = -1
    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds 500
        try {
            $tail = Get-Content $log -Tail 50 -ErrorAction SilentlyContinue
            foreach ($line in $tail) {
                # HandBrake JSON progress format: {"State":"WORKING","Working":{"Progress":0.5,"...}}
                if ($line -match '"Progress"\s*:\s*(\d+(?:\.\d+)?)') {
                    $p = [double]$Matches[1]
                    $pct = [math]::Round($p * 100, 1)
                    Write-Progress -Activity "Encoding: $(Split-Path $InputFile -Leaf)" -Status "$pct% complete" -PercentComplete $pct
                    # Report progress milestones
                    if ($pct -ge 25 -and $lastReportedPercent -lt 25) {
                        Write-Host "  → Encoding progress: 25%" -ForegroundColor Gray
                        $lastReportedPercent = 25
                    } elseif ($pct -ge 50 -and $lastReportedPercent -lt 50) {
                        Write-Host "  → Encoding progress: 50%" -ForegroundColor Gray
                        $lastReportedPercent = 50
                    } elseif ($pct -ge 75 -and $lastReportedPercent -lt 75) {
                        Write-Host "  → Encoding progress: 75%" -ForegroundColor Gray
                        $lastReportedPercent = 75
                    }
                }
            }
        } catch {
            # Suppress errors during polling (file may be locked or not yet created)
        }
    }

    Write-Progress -Activity "Encoding: $(Split-Path $InputFile -Leaf)" -Completed

    $exit = $proc.ExitCode

    return @{ Success = ($exit -eq 0); Log = $log }
}

function Ensure-PathExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

# --- Main ---
try {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  HandBrake Automate - DVD Rip Workflow" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Log "Starting DVD rip orchestrator" -Level INFO

    # Step 1: Tool Detection
    Write-Host "[1/6] Detecting required tools..." -ForegroundColor Cyan
    Write-Progress -Activity "DVD Rip Workflow" -Status "Detecting tools..." -PercentComplete 0
    
    # Determine MakeMKV path: prefer explicit parameter, then config, then auto-detect
    if ($MakeMKVPath) {
        $makeMKV = $MakeMKVPath
    } elseif ($cfg.MakeMKVPath) {
        $makeMKV = $cfg.MakeMKVPath
    } else {
        Write-Host "  → Searching for MakeMKV executable..." -ForegroundColor Gray
        $makeMKV = Find-Executable -Names @('makemkvcon','makemkvcon.exe')
    }
    if (-not $makeMKV) { Write-Log 'makemkvcon not found. Please install MakeMKV and ensure makemkvcon is on PATH, or pass -MakeMKVPath.' -Level ERROR; exit 1 }
    Write-Log "Found MakeMKV: $makeMKV" -Level INFO

    # Determine HandBrake path: prefer explicit parameter, then config, then auto-detect
    if ($HandBrakePath) {
        $handbrake = $HandBrakePath
    } elseif ($cfg.HandBrakePath) {
        $handbrake = $cfg.HandBrakePath
    } else {
        Write-Host "  → Searching for HandBrake CLI executable..." -ForegroundColor Gray
        $handbrake = Find-Executable -Names @('HandBrakeCLI','HandBrakeCLI.exe')
    }
    if (-not $handbrake) { Write-Log 'HandBrakeCLI not found. Please install HandBrakeCLI and ensure it is on PATH, or pass -HandBrakePath.' -Level ERROR; exit 1 }
    Write-Log "Found HandBrakeCLI: $handbrake" -Level INFO
    Write-Host "  ✓ All required tools detected" -ForegroundColor Green
    Write-Host ""

    # Step 2: Disc Detection
    Write-Host "[2/6] Detecting optical disc..." -ForegroundColor Cyan
    Write-Progress -Activity "DVD Rip Workflow" -Status "Detecting disc..." -PercentComplete 17
    $drive = Get-OpticalDriveWithDisc -MakeMKVPath $makeMKV
    if (-not $drive) { Write-Log 'No DVD found in optical drives.' -Level ERROR; exit 1 }
    Write-Log "Found disc in drive index $($drive.Index) — $($drive.DiscName)" -Level INFO
    Write-Host "  ✓ Disc detected: $($drive.DiscName)" -ForegroundColor Green
    Write-Host ""

    # Step 3: Reading Titles
    Write-Host "[3/6] Reading disc titles..." -ForegroundColor Cyan
    Write-Progress -Activity "DVD Rip Workflow" -Status "Reading titles..." -PercentComplete 33
    $titles = Get-DiscTitles -MakeMKVPath $makeMKV -DriveIndex $drive.Index
    if (-not $titles) { Write-Log 'No titles found on disc.' -Level ERROR; exit 1 }
    Write-Host "  ✓ Found $($titles.Count) title(s)" -ForegroundColor Green
    Write-Host ""

    # Step 4: Title Selection
    Write-Host "[4/6] Title Selection" -ForegroundColor Cyan
    Write-Progress -Activity "DVD Rip Workflow" -Status "Waiting for user selection..." -PercentComplete 50
    $selection = Prompt-SelectTitles -Titles $titles
    Write-Log "User selected: $selection" -Level INFO
    Write-Host "  ✓ Selection confirmed: $selection" -ForegroundColor Green
    Write-Host ""

    Ensure-PathExists -Path $TempPath
    Ensure-PathExists -Path $OutputPath

    # Step 5: Ripping Titles
    Write-Host "[5/6] Ripping selected titles..." -ForegroundColor Cyan
    Write-Host "  → Output directory: $TempPath" -ForegroundColor Gray
    Write-Progress -Activity "DVD Rip Workflow" -Status "Ripping titles..." -PercentComplete 60
    Write-Log "Ripping selected titles to temp: $TempPath" -Level INFO
    $ripRes = Start-MakeMKV-Rip -MakeMKVPath $makeMKV -DriveIndex $drive.Index -Selection $selection -OutDir $TempPath
    if (-not $ripRes.Success) {
        Write-Log "MakeMKV rip failed. See log: $($ripRes.Log)" -Level ERROR
        exit 1
    }
    Write-Log "Ripping completed. Log: $($ripRes.Log)" -Level INFO
    Write-Host "  ✓ Ripping completed successfully" -ForegroundColor Green
    Write-Host ""

    # Step 6: Encoding Files
    Write-Host "[6/6] Encoding to final format..." -ForegroundColor Cyan
    Write-Progress -Activity "DVD Rip Workflow" -Status "Encoding..." -PercentComplete 75
    Write-Host "  → Output directory: $OutputPath" -ForegroundColor Gray
    Write-Host "  → Format: $OutputFormat" -ForegroundColor Gray
    
    # Encode each MKV in temp
    $mkvFiles = Get-ChildItem -Path $TempPath -Filter '*.mkv' -File -ErrorAction SilentlyContinue
    if (-not $mkvFiles) { Write-Log 'No MKV files found in temp directory.' -Level ERROR; exit 1 }

    Write-Host "  → Processing $($mkvFiles.Count) file(s)..." -ForegroundColor Gray
    $encodedCount = 0
    $successCount = 0
    foreach ($file in $mkvFiles) {
        $encodedCount++
        $outFile = Join-Path $OutputPath ("$($file.BaseName).$OutputFormat")
        Write-Host ""
        Write-Host "Encoding file $encodedCount of $($mkvFiles.Count): $($file.Name)" -ForegroundColor Yellow
        Write-Log "Encoding $($file.Name) -> $outFile" -Level INFO
        $enc = Start-HandBrake-Encode -HandBrakePath $handbrake -InputFile $file.FullName -OutputFile $outFile -PresetFile $PresetFile -PresetName $PresetName -Format $OutputFormat
        if (-not $enc.Success) {
            Write-Log "HandBrake encode failed for $($file.Name). See log: $($enc.Log)" -Level ERROR
            Write-Log 'Keeping temp files for debugging.' -Level WARN
            exit 1
        }
        $successCount++
        Write-Log "Encoded successfully: $outFile" -Level INFO
        Write-Host "  ✓ Completed: $($file.Name)" -ForegroundColor Green
    }

    # This point is only reached if all files encoded successfully (otherwise we exit above)
    Write-Host ""
    Write-Host "  ✓ All $successCount file(s) encoded successfully" -ForegroundColor Green
    Write-Host ""
    Write-Progress -Activity "DVD Rip Workflow" -Status "Complete" -PercentComplete 100

    if (-not $KeepTemp) {
        Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
        Write-Log "Deleting temp MKV files in $TempPath" -Level INFO
        Get-ChildItem -Path $TempPath -Filter '*.mkv' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Temporary files removed" -ForegroundColor Green
    } else {
        Write-Log "KeepTemp specified; skipping temp deletion" -Level WARN
        Write-Host "  ℹ Temporary files preserved (KeepTemp flag set)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Workflow Complete!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Output location: $OutputPath" -ForegroundColor White
    Write-Host "  Files created: $($mkvFiles.Count)" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Log "All done. Output files are in: $OutputPath" -Level INFO
    exit 0
} catch {
    Write-Log ("Unhandled error: " + $_.Exception.Message) -Level ERROR
    exit 1
}
