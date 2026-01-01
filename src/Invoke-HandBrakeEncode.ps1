<#
Invoke-HandBrakeEncode.ps1
HandBrake CLI wrapper functions for importing presets, listing presets, and encoding files with progress parsing.
Exports:
- Get-HandBrake-Presets
- Invoke-HandBrake-Encode
- Invoke-HandBrake-EncodeBatch

Requires `HandBrakeCLI` available on PATH or provided explicitly.
#>

function Get-HandBrake-Presets {
    [CmdletBinding()]
    param(
        [string]$HandBrakePath = 'HandBrakeCLI'
    )
    try {
        $out = & $HandBrakePath -z 2>&1
        return $out
    } catch {
        Write-Warning "Failed to run HandBrakeCLI -z: $_"
        return $null
    }
}

function Invoke-HandBrake-Encode {
    [CmdletBinding()]
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [string]$PresetFile = $null,
        [string]$PresetName = $null,
        [ValidateSet('mp4','mkv')] [string]$Container = 'mp4',
        [string]$HandBrakePath = 'HandBrakeCLI',
        [int]$PollMs = 500
    )
    if (-not (Test-Path $InputFile)) { throw "Input file not found: $InputFile" }

    New-Item -ItemType Directory -Path (Split-Path $OutputFile) -Force | Out-Null

    Write-Host "Starting HandBrake encode..." -ForegroundColor Cyan
    Write-Host "  Input: $(Split-Path $InputFile -Leaf)" -ForegroundColor Gray
    Write-Host "  Output: $(Split-Path $OutputFile -Leaf)" -ForegroundColor Gray
    Write-Host "  Container: $Container" -ForegroundColor Gray
    if ($PresetName) { Write-Host "  Preset: $PresetName" -ForegroundColor Gray }

    $logFile = [IO.Path]::Combine((Split-Path $OutputFile), "handbrake_$(Split-Path $InputFile -Leaf)-$(Get-Random).log")

    # If a preset file is provided, try importing it and verify the preset name exists
    if ($PresetFile -and (Test-Path $PresetFile)) {
        try {
            $importOut = & $HandBrakePath --preset-import-file "$PresetFile" -z 2>&1
            $importText = $importOut -join "`n"
            if ($PresetName) {
                if ($importText -notmatch [regex]::Escape($PresetName)) {
                    Write-Host "WARNING: Preset '$PresetName' not found after import. Falling back to built-in preset 'Fast 1080p30'." -ForegroundColor Yellow
                    $PresetName = 'Fast 1080p30'
                }
            }
        } catch {
            Write-Host "WARNING: Failed to import preset file: $_. Falling back to built-in preset 'Fast 1080p30'." -ForegroundColor Yellow
            $PresetName = 'Fast 1080p30'
        }
    }

    $args = @()
    if ($PresetFile -and (Test-Path $PresetFile)) { $args += "--preset-import-file"; $args += "`"$PresetFile`"" }
    if ($PresetName) { $args += "-Z"; $args += "`"$PresetName`"" }
    $args += "-i"; $args += "`"$InputFile`""
    $args += "-o"; $args += "`"$OutputFile`""
    if ($Container -eq 'mp4') { $args += "-f"; $args += "av_mp4" } else { $args += "-f"; $args += "av_mkv" }
    $args += "--json"

    # Run HandBrakeCLI with progress monitoring
    $proc = Start-Process -FilePath $HandBrakePath -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput $logFile -RedirectStandardError $logFile

    $lastPercent = -1
    $lastMilestone = -1
    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds $PollMs
        try {
            $tail = Get-Content $logFile -Tail 50 -ErrorAction SilentlyContinue
            foreach ($line in $tail) {
                # HandBrake JSON progress format: {"State":"WORKING","Working":{"Progress":0.5,"...}}
                if ($line -match '"Progress"\s*:\s*([\d.]+)') {
                    $progress = [double]$Matches[1]
                    $pct = [math]::Round($progress * 100, 1)
                    if ($pct -ne $lastPercent) {
                        $lastPercent = $pct
                        Write-Progress -Activity 'HandBrake Encode' -Status "$pct% complete" -PercentComplete $pct
                        # Report milestones
                        if ($pct -ge 25 -and $lastMilestone -lt 25) {
                            Write-Host "  → Encoding progress: 25%" -ForegroundColor Gray
                            $lastMilestone = 25
                        } elseif ($pct -ge 50 -and $lastMilestone -lt 50) {
                            Write-Host "  → Encoding progress: 50%" -ForegroundColor Gray
                            $lastMilestone = 50
                        } elseif ($pct -ge 75 -and $lastMilestone -lt 75) {
                            Write-Host "  → Encoding progress: 75%" -ForegroundColor Gray
                            $lastMilestone = 75
                        }
                    }
                }
            }
        } catch { }
    }

    Write-Progress -Activity 'HandBrake Encode' -Completed

    $exit = $proc.ExitCode
    # Ensure final log capture
    Start-Sleep -Milliseconds 200
    $all = Get-Content $logFile -ErrorAction SilentlyContinue | Out-String

    # Optionally show last lines on failure for quick debugging
    if ($exit -ne 0) {
        Write-Host "✗ HandBrakeCLI exited with code $exit. Last 50 lines of log:" -ForegroundColor Red
        Get-Content $logFile -Tail 50 | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "✓ Encoding completed successfully" -ForegroundColor Green
    }

    return [PSCustomObject]@{ Success = ($exit -eq 0); ExitCode = $exit; Log = $logFile; Output = $all }
}

function Invoke-HandBrake-EncodeBatch {
    [CmdletBinding()]
    param(
        [string[]]$InputFiles,
        [string]$OutputDir,
        [string]$PresetFile = $null,
        [string]$PresetName = $null,
        [ValidateSet('mp4','mkv')] [string]$Container = 'mp4',
        [string]$HandBrakePath = 'HandBrakeCLI',
        [int]$PollMs = 500
    )
    if (-not $InputFiles) { throw 'No input files specified' }
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

    Write-Host "Starting batch encode of $($InputFiles.Count) file(s)..." -ForegroundColor Cyan

    $results = @()
    $fileNum = 0
    foreach ($in in $InputFiles) {
        $fileNum++
        Write-Host ""
        Write-Host "Processing file $fileNum of $($InputFiles.Count)..." -ForegroundColor Yellow
        $outFile = Join-Path $OutputDir ((Split-Path $in -LeafBase) + "." + $Container)
        $res = Invoke-HandBrake-Encode -InputFile $in -OutputFile $outFile -PresetFile $PresetFile -PresetName $PresetName -Container $Container -HandBrakePath $HandBrakePath -PollMs $PollMs
        $results += [PSCustomObject]@{ Input = $in; Output = $outFile; Success = $res.Success; ExitCode = $res.ExitCode; Log = $res.Log }
        if (-not $res.Success) { 
            Write-Host "✗ Batch encode stopped due to failure" -ForegroundColor Red
            break 
        }
    }
    
    Write-Host ""
    Write-Host "Batch encode complete: $(@($results | Where-Object {$_.Success}).Count) of $($InputFiles.Count) files succeeded" -ForegroundColor Cyan
    
    return $results
}

# Intentionally not exporting module members to allow dot-sourcing this script.
