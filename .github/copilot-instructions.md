# HandBrake Automate - GitHub Copilot Instructions

This file provides custom instructions for GitHub Copilot when working with the HandBrake Automate repository.

## Project Overview

HandBrake Automate is a PowerShell toolset for automating DVD ripping and encoding using MakeMKV and HandBrake CLI. The project consists of modular PowerShell scripts that orchestrate the workflow from disc detection to final video encoding.

## General Guidelines

- This is a PowerShell project (PowerShell 7+ and Windows PowerShell)
- Always use proper PowerShell conventions and best practices
- Keep code modular and maintainable
- Focus on Windows environments with optical disc drives
- Prioritize user experience with clear progress indicators and logging

## PowerShell Coding Standards

### Script Structure
- Use `[CmdletBinding()]` for all functions
- Include comprehensive comment-based help at the top of each script using `<# ... #>` blocks
- Document function purpose, parameters, and usage examples
- Use proper parameter validation (e.g., `[ValidateSet()]`, `[Parameter(Mandatory=$true)]`)

### Naming Conventions
- Use PowerShell verb-noun naming for functions (e.g., `Get-ToolPath`, `Invoke-DvdRip`)
- Use PascalCase for function names and parameters
- Use descriptive variable names with meaningful context

### Code Style
- Use 4 spaces for indentation (not tabs)
- Keep lines readable; break long commands into multiple lines using backticks or splatting
- Use single quotes for simple strings, double quotes when interpolation is needed
- Prefer `-ErrorAction SilentlyContinue` for expected failures during detection/probing

### Error Handling
- Use proper error handling with try-catch blocks where appropriate
- Log errors using `Write-Log` with level 'ERROR'
- Use `Write-Log` with appropriate levels: INFO, WARN, ERROR, DEBUG
- Always provide meaningful error messages to users

## Project Architecture

### Core Files (src/)
- `Invoke-DvdRip.ps1` — Main orchestrator script coordinating the entire workflow
- `Invoke-MakeMKV.ps1` — Wrapper for MakeMKV operations (drive detection, title listing, ripping)
- `Invoke-HandBrakeEncode.ps1` — Wrapper for HandBrake encoding operations
- `Config.ps1` — Configuration management (tool path detection, load/save settings)
- `Logger.ps1` — Centralized logging utilities
- `config.json` — Persistent configuration (created at runtime, not in repo)
- `presets/` — HandBrake JSON preset files

### Tool Scripts (tools/)
- `syntax_check.ps1` — PowerShell syntax validation for all source files
- `demo_progress.ps1` — Demonstration script showing workflow without hardware
- Other utility scripts for testing and configuration

## Configuration Management

### Tool Path Detection
- Use `Get-ToolPath` function from `Config.ps1` for detecting external tools
- Check PATH first, then common Windows Program Files locations
- Support both `makemkvcon.exe` and `HandBrakeCLI.exe`
- Persist detected or user-provided paths to `config.json` for future runs
- Never hardcode tool paths

### Config File Pattern
- Configuration is stored in `src/config.json` (created at runtime)
- Use `Get-DefaultConfig` to load configuration with auto-detection fallback
- Use `Save-Config` to persist configuration changes
- Support both command-line parameters and config file defaults
- Command-line parameters always override config file settings

## Logging Conventions

### Using the Logger
- Always initialize logger with `Initialize-Logger -LogDir` at the start of main scripts
- Use dot-sourcing to load Logger.ps1: `. "$ScriptDir\Logger.ps1"`
- Log important operations and state changes
- Include context in log messages (file paths, operation names, etc.)

### Log Levels
- **INFO**: Normal operational messages, successful operations, progress updates
- **WARN**: Non-critical issues, fallback behaviors, deprecated usage
- **ERROR**: Failures, exceptions, critical problems that prevent operation
- **DEBUG**: Detailed diagnostic information for troubleshooting

### Log Files
- Session logs are created in `src/logs/` directory with timestamp: `automate_handbrake_YYYYMMDD_HHmmss.log`
- Individual operation logs may be created next to output files
- Log files are in `.gitignore` and should not be committed

## Progress and User Feedback

### Progress Indicators
- Use step indicators for multi-stage workflows: `[1/6] Step description...`
- Implement milestone progress reporting at 25%, 50%, and 75% for long operations
- Use native PowerShell `Write-Progress` cmdlet for progress bars
- Show percentage completion when possible

### Status Icons and Colors
- ✓ (checkmark) for completed steps with Green
- → (arrow) for ongoing operations with Gray
- ℹ (info) for informational messages with Yellow
- ✗ (X) for errors with Red

### User Interaction
- Provide clear prompts for user input (e.g., title selection)
- Display configuration and detected settings before starting operations
- Show summary information on completion
- Give users option to preserve temporary files with `-KeepTemp` switch

## Testing and Validation

### Syntax Checking
- Run `tools/syntax_check.ps1` to validate PowerShell syntax for all source files
- This is the primary validation method before committing changes
- Uses PowerShell's built-in parser to detect syntax errors

### Testing Approach
- Use `tools/demo_progress.ps1` to demonstrate workflow without hardware
- Create utility scripts in `tools/` directory for testing specific functionality
- Test scripts should be self-contained and not require actual DVD hardware when possible
- No formal test framework is used; validation is manual and script-based

### Build Commands
```powershell
# Syntax validation (always run before committing)
pwsh -NoProfile -File tools/syntax_check.ps1

# Demo workflow (no hardware required)
pwsh -NoProfile -File tools/demo_progress.ps1
```

## File Organization

### Directory Structure
```
/
├── src/                    # Core PowerShell scripts and modules
│   ├── presets/           # HandBrake JSON preset files
│   ├── logs/              # Runtime logs (gitignored)
│   └── config.json        # Runtime configuration (gitignored)
├── tools/                  # Utility and testing scripts
├── .github/               # GitHub configuration
└── [README.md, etc.]      # Documentation
```

### Temporary Files
- Default temp path: `$env:TEMP\dvd_rip_temp`
- Temp files are automatically cleaned up unless `-KeepTemp` is specified
- Never commit temporary files, build artifacts, or runtime-generated content

## External Dependencies

### Required Tools
- **MakeMKV** (`makemkvcon.exe`) — DVD ripping to MKV format
- **HandBrake CLI** (`HandBrakeCLI.exe`) — Video encoding and transcoding

### Tool Detection Logic
1. Check if executable is on PATH using `Get-Command`
2. Check common Program Files locations:
   - `C:\Program Files\<tool>\<tool>.exe`
   - `C:\Program Files (x86)\<tool>\<tool>.exe`
3. Use cached path from `config.json` if available
4. Prompt user or fail gracefully if not found

## Common Patterns

### Script Initialization
```powershell
# Load dependencies
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$ScriptDir\Config.ps1"
. "$ScriptDir\Logger.ps1"

# Initialize logger
Initialize-Logger -LogDir (Join-Path $ScriptDir 'logs') | Out-Null

# Load configuration
$configFile = Join-Path $ScriptDir 'config.json'
$cfg = Get-DefaultConfig -ConfigFile $configFile
```

### Progress Reporting
```powershell
Write-Log "[1/6] Step description..." -Level INFO
Write-Progress -Activity "Operation" -Status "Progress" -PercentComplete 50
```

### Tool Execution
```powershell
# Redirect all output to log file
& $toolPath $arguments *> $logFile 2>&1

# Parse log file for results
$lines = Get-Content $logFile -ErrorAction SilentlyContinue
```

## Documentation Standards

### README Files
- Keep README.md updated with current workflow and examples
- Include prerequisites, quick start guide, and troubleshooting section
- Document all command-line parameters and configuration options
- Provide working examples that users can copy-paste

### Code Comments
- Use comment-based help for all functions and main scripts
- Comment complex logic or non-obvious operations
- Keep comments concise and relevant
- Update comments when code changes

### Change Documentation
- Document significant enhancements in dedicated markdown files (see PROGRESS_ENHANCEMENTS.md)
- Include rationale, modified files, and benefits of changes
- Keep backward compatibility notes when relevant

## Security Considerations

- Never commit sensitive data (paths that might contain usernames, API keys, etc.)
- Be cautious with log file contents
- Validate and sanitize user input before using in file operations
- Use proper parameter validation to prevent injection or path traversal

## Common Tasks for Copilot

When asked to add features or fix issues:
1. Understand the existing patterns by reading relevant source files
2. Follow the established coding style and conventions
3. Update logging and progress indicators appropriately
4. Test syntax with `tools/syntax_check.ps1`
5. Update documentation if user-facing behavior changes
6. Consider backward compatibility and existing workflows
7. Use proper error handling and user feedback

## Workflow Steps (for reference)

The typical DVD rip workflow follows these stages:
1. Tool detection (MakeMKV and HandBrake)
2. Optical disc detection
3. Read disc titles and metadata
4. User selects titles to rip
5. MakeMKV rips selected titles to temp MKV files
6. HandBrake encodes MKV files to final format (mp4/mkv)
7. Cleanup temp files (unless `-KeepTemp` specified)
