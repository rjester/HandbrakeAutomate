# Example: run orchestrator with explicit tool paths and persist them to config
pwsh ./src/Invoke-DvdRip.ps1 -MakeMKVPath 'C:\Program Files\MakeMKV\makemkvcon.exe' -HandBrakePath 'C:\Program Files\HandBrake\HandBrakeCLI.exe' -OutputPath C:\Videos -PresetFile ./src/presets/DvdRip.json -PresetName 'DvdRip Balanced' -OutputFormat mp4
