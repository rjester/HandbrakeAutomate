<#
Logger.ps1
Simple logger utilities for the DVD rip tools.
Functions:
- Initialize-Logger -LogDir <dir>  # returns log file path
- Write-Log -Message <string> -Level <INFO|WARN|ERROR|DEBUG>
- Get-LogPath

Logs are appended to a timestamped file under the provided log dir.
#>

$Global:__AH_LogFile = $null

function Initialize-Logger {
    [CmdletBinding()]
    param(
        [string]$LogDir = "$PSScriptRoot\\logs"
    )
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    $file = Join-Path $LogDir ("automate_handbrake_$(Get-Date -Format 'yyyyMMdd_HHmmss').log")
    New-Item -Path $file -ItemType File -Force | Out-Null
    $Global:__AH_LogFile = $file
    return $file
}

function Get-LogPath {
    return $Global:__AH_LogFile
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')] [string]$Level = 'INFO'
    )
    if (-not $Global:__AH_LogFile) { Initialize-Logger | Out-Null }
    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$time] [$Level] $Message"

    switch ($Level) {
        'INFO'  { Write-Host $line -ForegroundColor Green }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'DEBUG' { Write-Host $line -ForegroundColor DarkGray }
    }

    try {
        Add-Content -Path $Global:__AH_LogFile -Value $line -Encoding UTF8
    } catch {
        Write-Host "Failed to write to log file: $_" -ForegroundColor Red
    }
}

# Intentionally not exporting module members to allow dot-sourcing this script.
