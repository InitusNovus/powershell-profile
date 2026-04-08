# PowerShell Profile - AI Coding Agent Instructions

> **Important (oh-my-posh prompt):** The customized prompt can make automated command completion detection unreliable. When running automated tests or scripted commands, temporarily disable the oh-my-posh init block (or comment it out) to avoid hangs. Do not attempt to parse the theme JSON to detect prompt completion.
>
> **Prompt pattern reference** (from `clean-detailed_custom.omp_V2.2.json`):
> - Final prompt line always ends with: `╰─ ` (Unicode: `\u2570\u2500 `)
> - Transient prompt (after command): ` ` (Unicode: `\ue285 `)
> - This info is for debugging reference only; terminal tools cannot use pattern matching for completion detection.

## Testing Guidelines

**DO NOT** reload the profile with `. $PROFILE` in automated terminal commands — this re-initializes oh-my-posh and breaks command completion detection.

**Instead, use this workflow:**
1. Make edits to the profile
2. Open a **new terminal** (which loads the profile automatically)
3. Test individual functions directly (e.g., `Get-PythonVersion`, `Show-StartupBanner -Force`)
4. Simple commands like `Get-Date`, `Write-Host`, etc. work fine for quick checks

**Safe test commands** (can be run via `run_in_terminal`):
```powershell
Get-PythonVersion
Get-UvPythonPath
Get-VenvName
Show-Msys2Toolchain
Reset-Path
```

**Avoid in automated runs:**
```powershell
. $PROFILE          # Re-initializes oh-my-posh, hangs
oh-my-posh init ... # Same issue
```

## Project Overview
This is a cross-platform PowerShell profile system for managing development environments. The main file (`Microsoft.PowerShell_profile.ps1`) provides unified PATH management, Python/uv environment switching, MSYS2 toolchain control, and environment status visualization.

## Architecture & Key Components

### File Structure
- `Microsoft.PowerShell_profile.ps1` - Main profile (770 lines, 11 functional sections)
- `Microsoft.VSCode_profile.ps1` - Simplified VS Code profile (loads oh-my-posh + folder shortcuts)
- `config.psd1` - External configuration file (theme, paths, MSYS2 root)
- `clean-detailed_custom.omp_V2.2.json` - oh-my-posh theme configuration
- `PowerShell_Profile_Analysis.md` - Comprehensive code review and refactoring guide

### Functional Sections (in load order, 2026-02-04 기준)
1. **macOS PATH Extension** (7-10): Conditional `$env:PATH` for non-Windows
2. **Config Loading** (12-51): `Import-ProfileConfig`, `Resolve-ProfilePath`, config.psd1 merge
3. **oh-my-posh Init** (53-68): Theme loader with fallback, Shell Integration for VS Code
4. **User Folder Shortcuts** (74-79): `$DESKTOP`, `$DEV`, `$GOOGLEDRIVE` globals (config-based)
5. **PATH Utilities** (82-164): Core infrastructure - `Get-PathEntries`, `Remove-PathEntry`, `Prepend-PathEntry`, `Reset-Path`
6. **uv Global venv** (171-276): Virtual environment activation with `Activate-UvGlobal`/`Deactivate-UvGlobal` (with `-Force` guard)
7. **Python Helpers** (278-408): Version detection, venv name parsing (cross-platform), environment info
8. **uv Managed Python Policy** (409-476): Toggle `UV_NO_MANAGED_PYTHON` environment variable
9. **nanopb Helper** (479-488): Protobuf generator wrapper
10. **MSYS2 Toolchain** (511-651): Windows gcc/g++ preference switching (`Use-UCRT64`, `Use-MINGW64`)
11. **Startup Banner** (656-762): Console-width-aware status display

## Critical Patterns & Conventions

### Cross-Platform Handling
```powershell
if ($IsWindows) { 
    # Windows-specific logic
} else { 
    # macOS/Linux logic  
}
```
**Rule**: Always check `$IsWindows` for OS-specific operations. Use `Join-Path` instead of hardcoded separators.

### PATH Manipulation Standard
```powershell
# CORRECT: Use utility functions
Remove-PathEntry "C:\Python39"
Prepend-PathEntry "C:\msys64\ucrt64\bin"

# WRONG: Direct string manipulation
$env:PATH = $env:PATH -replace "C:\Python39;", ""
```
**Why**: Utilities handle normalization, deduplication, and cross-platform separators.

### Function Naming Conflicts
- `Remove-PathEntry` (lines 66-71) vs `Remove-PathEntryFromEnv` (lines 112-118) - **DUPLICATION BUG**
- Both do the same thing but with different normalization logic
- **Rule**: Use `Remove-PathEntry` for new code; `Remove-PathEntryFromEnv` exists only for backward compatibility in uv section

### Global Variables Pattern
```powershell
# Configuration globals (set at top)
$Global:UvGlobalVenv = Join-Path $HOME "dev/_global-py/.venv"
$global:MSYS2_ROOT = "C:\msys64"

# Script-scoped state (internal)
$script:PATH_BASELINE = $env:Path
$script:STARTUP_BANNER_SHOWN = $false
```
**Rule**: Use `$Global:` for user-configurable paths, `$script:` for internal state tracking.

### Error Handling Style
```powershell
# Standard pattern for command existence checks
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) { return $py.Source }
return $null

# External command invocation
try {
    $result = python --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $result) { 
        return $result.Trim()
    }
} catch { }
return $null
```
**Rule**: Always use `-ErrorAction SilentlyContinue` for optional tools. Check `$LASTEXITCODE` after external commands.

### Alias Strategy
```powershell
# Provide both descriptive and short aliases
Set-Alias pywhere Get-PythonExecutable  # Long name (discoverable)
Set-Alias pyw     Get-PythonExecutable  # Short name (fast typing)
```
**Rule**: Create aliases AFTER function definitions. Use consistent prefixes (py*, uv*, ga/gde).

## Known Issues & Workarounds

### 1. VIRTUAL_ENV Collision Risk
`Activate-UvGlobal` overwrites `$env:VIRTUAL_ENV` without backup (line 129). If a project venv is active, it gets lost.
```powershell
# Current behavior (UNSAFE)
$env:VIRTUAL_ENV = $venv  # Overwrites existing

# Recommended check before modifying
if ($env:VIRTUAL_ENV) {
    Write-Warning "Another venv is active: $env:VIRTUAL_ENV"
    return
}
```

### 2. Windows-Only Regex in Get-VenvName
Line 213 pattern: `'\\([^\\]+)\\(\.?venv[^\\]*)\\Scripts\\python\.exe$'`  
Fails on Unix paths. Check `$IsWindows` before using.

### 3. PATH Baseline Persistence
`$script:PATH_BASELINE` set once at profile load (line 42). Reloading profile (`. $PROFILE`) won't update baseline if PATH changed externally.
```powershell
# Force update: call Rebaseline-Path after system changes
Rebaseline-Path
```

## Development Workflows

### Testing Profile Changes
```powershell
# 1. Edit Microsoft.PowerShell_profile.ps1
# 2. Reload without restarting PowerShell
. $PROFILE

# 3. Verify banner shows updated info
Show-StartupBanner -Force

# 4. Check for errors
$Error[0]
```

### Adding New Environment Section
1. Create function block at bottom (before startup banner section)
2. Add `Show-*Banner` function following pattern:
   ```powershell
   function Show-MyToolBanner {
       Write-BannerLine -Header "[MyTool]" -Label "version" -Value "1.0"
   }
   ```
3. Call from `Show-StartupBanner` (line 595+)
4. Export aliases at end of section

### Debugging PATH Issues
```powershell
# View current PATH entries (numbered)
Get-PathEntries | ForEach-Object { $i=1 } { "$i. $_"; $i++ }

# Check MSYS2 toolchain conflicts
Show-Msys2Toolchain

# See which gcc is active
(Get-Command gcc -ErrorAction SilentlyContinue)?.Source

# Reset to session start
Reset-Path
```

### Banner Width Issues
Terminal too narrow? Adjust fallback in `Get-ConsoleWidthSafe` (line 529):
```powershell
param([int]$Fallback = 74)  # Change to your terminal width
```

## External Dependencies
- **oh-my-posh**: Prompt theme engine (optional - graceful fallback)
- **uv**: Python package/environment manager (functions fail silently if missing)
- **MSYS2**: Windows gcc/g++ toolchains (Windows-only, paths hardcoded to `C:\msys64`)

## Testing Commands
```powershell
# Verify Python detection
pywhere    # Show active Python path
pyinfo     # Full environment info
pyuv       # uv-managed Python path

# Check uv policy
uvpolicy   # Shows if managed Python is blocked

# PATH management
Reset-Path              # Restore to session start
Rebaseline-Path         # Update baseline to current state
Remove-PathEntry "..."  # Remove specific entry

# MSYS2 switching (Windows only)
Use-UCRT64    # Prefer UCRT64 gcc
Use-MINGW64   # Prefer MINGW64 gcc
Show-Msys2Toolchain  # Detailed status
```

## Current Refactoring Focus
- Keep everything in a single profile file for now (no module split yet).
- Prioritize refactoring the existing code without changing current behavior or banner output.
- When refactoring, design for future extensibility (clean helpers, clear boundaries, minimal coupling).
- Implement config externalization now (move hardcoded paths/values into `config.psd1` and load it in profile).

## Later (Memo)
- Split into modules: `PathUtils.psm1`, `PythonEnv.psm1`, `Msys2Toolchain.psm1`
- Add environment health check (`Test-EnvironmentHealth`)
- Implement preset system for quick environment switching

## When Modifying This Profile
1. **Preserve backward compatibility**: Existing aliases must keep working
2. **Test on both platforms**: Use `$IsWindows` checks, test macOS paths if possible
3. **Update analysis doc**: Reflect changes in `PowerShell_Profile_Analysis.md`
4. **Follow naming conventions**: Verb-Noun pattern, consistent prefixes
5. **Add Comment-Based Help**: Use `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE` for new functions
6. **Behavior parity**: Refactors must not change current outputs or banner formatting (use the existing commands to verify)
