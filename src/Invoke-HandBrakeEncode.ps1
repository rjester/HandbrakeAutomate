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

    # Run HandBrakeCLI and capture all output into the log file
    try {
        $procOutput = & $HandBrakePath @args 2>&1 | Tee-Object -FilePath $logFile
        $exit = $LASTEXITCODE
    } catch {
        $procOutput = $_ | Out-String
        $exit = 1
        Add-Content -Path $logFile -Value $procOutput -Encoding utf8
    }

    # Ensure we always write output to log and return the result
    $all = Get-Content $logFile -ErrorAction SilentlyContinue | Out-String

    # Optionally show last lines on failure for quick debugging
    if ($exit -ne 0) {
        Write-Host "HandBrakeCLI exited with code $exit. Last 50 lines of log:" -ForegroundColor Red
        Get-Content $logFile -Tail 50 | ForEach-Object { Write-Host $_ }
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

    $results = @()
    foreach ($in in $InputFiles) {
        $outFile = Join-Path $OutputDir ((Split-Path $in -LeafBase) + "." + $Container)
        $res = Invoke-HandBrake-Encode -InputFile $in -OutputFile $outFile -PresetFile $PresetFile -PresetName $PresetName -Container $Container -HandBrakePath $HandBrakePath -PollMs $PollMs
        $results += [PSCustomObject]@{ Input = $in; Output = $outFile; Success = $res.Success; ExitCode = $res.ExitCode; Log = $res.Log }
        if (-not $res.Success) { break }
    }
    return $results
}

# Intentionally not exporting module members to allow dot-sourcing this script.
