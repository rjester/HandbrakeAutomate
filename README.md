# AutomateHandbrake

PowerShell toolset to rip a single DVD using MakeMKV (`makemkvcon`) to extract MKV files and HandBrake CLI (`HandBrakeCLI`) to encode the results into `mp4` or `mkv` using a custom JSON preset.

## Contents
- `src/Invoke-DvdRip.ps1` — orchestrator (auto-detects tools, interactive title selection, rip → encode, temp cleanup)
- `src/Invoke-MakeMKV.ps1` — MakeMKV wrapper (drive detection, title listing, ripping)
- `src/Invoke-HandBrakeEncode.ps1` — HandBrake wrapper (preset import, encode, progress)
- `src/Config.ps1` — auto-detect / load/save defaults
- `src/Logger.ps1` — simple logging utilities
- `src/presets/DvdRip.json` — example HandBrake JSON preset
- `tools/syntax_check.ps1` — quick local syntax checker

## Prerequisites
- Windows with an optical drive containing the DVD you want to rip.
- MakeMKV installed (makemkvcon on `PATH` or install location detected).
  - https://www.makemkv.com/
- HandBrake CLI installed (HandBrakeCLI on `PATH` or install location detected).
  - https://handbrake.fr/docs/en/latest/cli/cli-guide.html
- PowerShell (tested on PowerShell 7+ and Windows PowerShell).

## Quick Start
1. (Optional) Run the syntax checker:
```powershell
pwsh -NoProfile -File tools\syntax_check.ps1
```

2. Run the orchestrator (example):
```powershell
pwsh ./src/Invoke-DvdRip.ps1 -OutputPath C:\Videos -PresetFile ./src/presets/DvdRip.json -PresetName "DvdRip Balanced" -OutputFormat mp4
```

Persist tool paths (optional):
If `makemkvcon` or `HandBrakeCLI` are not on `PATH`, you can pass absolute paths; the script will persist them to `src/config.json` for future runs:
```powershell
pwsh ./src/Invoke-DvdRip.ps1 -MakeMKVPath 'C:\Program Files\MakeMKV\makemkvcon.exe' -HandBrakePath 'C:\Program Files\HandBrake\HandBrakeCLI.exe' -OutputPath C:\Videos -PresetFile ./src/presets/DvdRip.json -PresetName 'DvdRip Balanced' -OutputFormat mp4
```

Notes:
- The script auto-detects `makemkvcon` and `HandBrakeCLI` from `PATH` or common Program Files locations.
- By default the script stores temporary MKV files under `%TEMP%\dvd_rip_temp` and deletes them after successful encodes. Use `-KeepTemp` to preserve them for debugging.
- Use `-PresetFile` and `-PresetName` to import and select a custom HandBrake preset JSON for per-run configuration.

## Configuration
- Default config lives at `src/config.json` (created when you call `Save-Config` from `src/Config.ps1`).
- To override defaults, edit the config JSON or pass parameters to `Invoke-DvdRip.ps1`.

## Logs
- A session log is created under `src/logs` (initialized by `Logger.ps1`).
- Individual MakeMKV/HandBrake per-run logs are written next to outputs and are referenced in console output.

## Troubleshooting
- If the script cannot find `makemkvcon` or `HandBrakeCLI`, ensure the executable is installed and on `PATH` or update `src/config.json` with absolute paths.
- If ripping or encoding fails, inspect the per-run logs referenced in console output and the session log under `src/logs`.
- For permission errors, run PowerShell as Administrator.

## Customizing presets
- HandBrake presets are standard JSON files. See `src/presets/DvdRip.json` for an example.
- You can export/import presets with HandBrake (`HandBrakeCLI --preset-import-file <file> -Z "Name"`).

## Next steps / Safety
- This repository implements a single-disc interactive flow. For unattended batch workflows, add a `-BatchMode` option that auto-selects the main feature.

If you want, I can now run a dry test (no disc required) to validate flow up to title discovery, or update the orchestrator to `Import-Module` the wrapper files instead of dot-sourcing. Let me know which you prefer.
