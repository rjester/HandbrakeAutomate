# AutomateHandbrake

A comprehensive DVD ripping solution featuring PowerShell automation scripts and a companion documentation website. Automate the process of extracting content from DVDs using MakeMKV and encoding to modern formats with HandBrake CLI.

## Features

- **Automated DVD Ripping**: Extract titles from DVDs using MakeMKV
- **Flexible Encoding**: Convert to MP4 or MKV using HandBrake presets
- **Interactive Title Selection**: Choose specific titles or select multiple with comma-separated input
- **Smart Tool Detection**: Auto-detects MakeMKV and HandBrake installations
- **Progress Tracking**: Real-time progress bars and milestone reporting
- **Companion Website**: Modern React-based documentation and quick-start guide
- **Comprehensive Logging**: Session and per-operation logs for troubleshooting

## Project Structure

### PowerShell Scripts (`src/`)
- `Invoke-DvdRip.ps1` — Main orchestrator script coordinating the entire workflow
- `Invoke-MakeMKV.ps1` — MakeMKV wrapper for drive detection, title listing, and ripping
- `Invoke-HandBrakeEncode.ps1` — HandBrake wrapper for preset-based encoding
- `Config.ps1` — Configuration management with auto-detection and persistence
- `Logger.ps1` — Centralized logging utilities
- `presets/` — HandBrake JSON preset files
- `logs/` — Runtime session logs (gitignored)
- `config.json` — Persistent configuration (gitignored)

### Companion Website (`website/`)
- React + Vite + TypeScript application
- Modern, responsive design with light/dark theme toggle
- Interactive quick-start guide and feature documentation
- Deployable to GitHub Pages

### Tools (`tools/`)
- `syntax_check.ps1` — PowerShell syntax validation
- `demo_progress.ps1` — Workflow demonstration without hardware
- Additional utility scripts for testing and configuration

## Prerequisites

### For DVD Ripping
- Windows with an optical drive containing a DVD
- MakeMKV installed (`makemkvcon.exe`)
  - Download: https://www.makemkv.com/
- HandBrake CLI installed (`HandBrakeCLI.exe`)
  - Download: https://handbrake.fr/downloads.html
- PowerShell 7+ (or Windows PowerShell)

### For Website Development
- Node.js 18+ and npm
- Git (for deployment to GitHub Pages)

## Quick Start

### DVD Ripping
1. Run syntax validation:
```powershell
pwsh -NoProfile -File tools\syntax_check.ps1
```

2. Execute the main script:
```powershell
pwsh ./src/Invoke-DvdRip.ps1 -OutputPath C:\Videos -PresetFile ./src/presets/DvdRip.json -PresetName "DvdRip Balanced" -OutputFormat mp4
```

3. Follow the interactive prompts to select titles (comma-separated, e.g., "0,1,2")

### Website Development
1. Install dependencies:
```bash
cd website
npm install
```

2. Start development server:
```bash
npm run dev
```

3. Build for production:
```bash
npm run build
```

4. Deploy to GitHub Pages:
```bash
npm run deploy
```

## Configuration

### Tool Path Detection
The scripts automatically detect MakeMKV and HandBrake from:
- `PATH` environment variable
- Common Program Files locations
- Previously saved paths in `src/config.json`

To manually specify paths:
```powershell
pwsh ./src/Invoke-DvdRip.ps1 -MakeMKVPath 'C:\Program Files\MakeMKV\makemkvcon.exe' -HandBrakePath 'C:\Program Files\HandBrake\HandBrakeCLI.exe' ...
```

### HandBrake Presets
- Use JSON preset files for consistent encoding settings
- Example preset included: `src/presets/DvdRip.json`
- Export presets from HandBrake GUI for custom configurations

### Temporary Files
- Default temp location: `%TEMP%\dvd_rip_temp`
- Automatically cleaned up after successful encoding
- Use `-KeepTemp` to preserve files for debugging

## Usage Examples

### Basic DVD Rip
```powershell
pwsh ./src/Invoke-DvdRip.ps1 -OutputPath C:\Videos -OutputFormat mp4
```

### Custom Preset
```powershell
pwsh ./src/Invoke-DvdRip.ps1 -OutputPath C:\Videos -PresetFile ./src/presets/DvdRip.json -PresetName "DvdRip Balanced"
```

### Multiple Titles
When prompted, enter: `0,1,2` to rip titles 0, 1, and 2

### Keep Temporary Files
```powershell
pwsh ./src/Invoke-DvdRip.ps1 -OutputPath C:\Videos -KeepTemp
```

## Logging and Troubleshooting

### Log Files
- Session logs: `src/logs/automate_handbrake_YYYYMMDD_HHmmss.log`
- Operation logs: Created alongside output files
- Console output includes log file paths for detailed diagnostics

### Common Issues
- **Tool not found**: Ensure MakeMKV/HandBrake are installed and accessible
- **Permission errors**: Run PowerShell as Administrator
- **Encoding failures**: Check HandBrake preset compatibility
- **Multiple title selection**: Use comma-separated format (e.g., "0,1,2")

### Validation
Run the syntax checker before committing changes:
```powershell
pwsh -NoProfile -File tools\syntax_check.ps1
```

## Development

### PowerShell Standards
- Uses `[CmdletBinding()]` and proper parameter validation
- Comprehensive comment-based help
- Follows PowerShell naming conventions (verb-noun)
- Error handling with try/catch and proper logging

### Website Architecture
- React 18 with TypeScript for type safety
- Vite for fast development and optimized builds
- CSS custom properties for theming
- Responsive design with modern UI patterns

## Contributing

1. Test changes with `tools/syntax_check.ps1`
2. Update documentation for user-facing changes
3. Follow established coding patterns
4. Test with actual DVD hardware when possible

## License

This project is open source. See individual file headers for license information.
