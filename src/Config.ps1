<#
Config.ps1
Provides functions to discover tool paths and load/save default settings.
Functions:
- Get-ToolPath([string[]]$Names)
- Get-DefaultConfig([string]$ConfigFile)
- Save-Config($Config, [string]$ConfigFile)

Configuration keys:
- MakeMKVPath
- HandBrakePath
- PresetFile (default HandBrake presets location)
- DefaultOutputPath
- DefaultTempPath
#>

function Get-ToolPath {
    [CmdletBinding()]
    param(
        [string[]]$Names
    )
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }

    # Common Windows locations
    $candidates = @()
    foreach ($name in $Names) {
        $candidates += "$env:ProgramFiles\\$name"
        $candidates += "$env:ProgramFiles(x86)\\$name"
        $candidates += "C:\\Program Files\\$name\\$name.exe"
        $candidates += "C:\\Program Files (x86)\\$name\\$name.exe"
        $candidates += "C:\\Program Files\\$name.exe"
        $candidates += "C:\\Program Files (x86)\\$name.exe"
    }

    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

function Get-DefaultConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigFile = "$PSScriptRoot\\config.json",
        [switch]$SaveDetected
    )

    $cfg = [ordered]@{
        MakeMKVPath = $null
        HandBrakePath = $null
        PresetFile = "$env:USERPROFILE\\AppData\\Roaming\\HandBrake\\presets.json"
        DefaultOutputPath = "$PWD\\output"
        DefaultTempPath = "$env:TEMP\\dvd_rip_temp"
    }

    # Attempt auto-detect
    if (-not $cfg.MakeMKVPath) {
        $mk = Get-ToolPath -Names @('makemkvcon','makemkvcon.exe')
        if ($mk) { $cfg.MakeMKVPath = $mk }
    }
    if (-not $cfg.HandBrakePath) {
        $hb = Get-ToolPath -Names @('HandBrakeCLI','HandBrakeCLI.exe')
        if ($hb) { $cfg.HandBrakePath = $hb }
    }

    # If a config file exists, merge values
    if (Test-Path $ConfigFile) {
        try {
            $json = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            foreach ($k in $json.PSObject.Properties.Name) {
                if ($json.$k -and ($cfg.Keys -contains $k)) { $cfg[$k] = $json.$k }
            }
        } catch {
            Write-Warning ("Failed to read config file {0}: {1}" -f $ConfigFile, $_)
        }
    }

    if ($SaveDetected) {
        try {
            Save-Config -Config ([PSCustomObject]$cfg) -ConfigFile $ConfigFile | Out-Null
        } catch {
            Write-Warning ("Failed to save detected config to {0}: {1}" -f $ConfigFile, $_)
        }
    }

    return [PSCustomObject]$cfg
}

function Save-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [psobject]$Config,
        [string]$ConfigFile = "$PSScriptRoot\\config.json"
    )
    $json = $Config | ConvertTo-Json -Depth 5
    $dir = Split-Path $ConfigFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json | Out-File -FilePath $ConfigFile -Encoding utf8
    return $ConfigFile
}

# Intentionally not exporting module members to allow dot-sourcing this script.
