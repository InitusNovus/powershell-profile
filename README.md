# PowerShell Profile

Reusable `pwsh` profile setup for Windows-first development, with optional extras for:

- [Oh My Posh](https://ohmyposh.dev/) prompt theming
- Python + `uv` environment helpers
- MSYS2 toolchain switching
- Startup status banner and built-in profile help
- VS Code terminal integration

This repository is structured so that shared behavior stays in Git, while machine-specific paths stay local.

## What this repository contains

- `Microsoft.PowerShell_profile.ps1` — main profile entrypoint
- `Microsoft.VSCode_profile.ps1` — VS Code wrapper that loads the main profile
- `config.template.psd1` — tracked shared defaults
- `config.local.psd1` — optional local overrides, intentionally ignored by Git
- `theme/clean-detailed_custom.omp.json` — active Oh My Posh theme
- `theme/archive/` — older theme snapshots
- `docs/PowerShell_Profile_Analysis.md` — design notes and analysis
- `.vscode/settings.template.json` — optional VS Code workspace template

## Features

### Prompt and shell UX

- Oh My Posh prompt with a custom theme
- Path icon mapping driven by exported `POSH_*` environment variables
- Styled startup banner showing Python, `uv`, MSYS2, and help entrypoints
- Built-in help entrypoint:

```powershell
phelp
phelp -d
phelp -s
phelp -c
phelp -a
```

### Folder shortcuts

The profile creates shortcut variables such as:

- `$DESKTOP`
- `$DEV`
- `$WORKSPACE` / `$WS`
- `$OPENCODE` / `$OC`
- `$GOOGLEDRIVE` / `$GDRIVE` / `$GD` (only when configured locally)

### Python and uv helpers

- Global `uv` venv activation/deactivation
- Python / pip path inspection helpers
- `uv` managed-Python policy toggles

### MSYS2 helpers

- Toolchain preference switching between `UCRT64` and `MINGW64`
- Current MSYS2 path/tool resolution inspection

## Requirements

### Required

- [PowerShell 7+ (`pwsh`)](https://learn.microsoft.com/powershell/)

### Recommended

- [Oh My Posh](https://ohmyposh.dev/docs/installation/windows)
- A Nerd Font for prompt glyphs

### Optional

- [`uv`](https://docs.astral.sh/uv/) for Python workflow helpers
- MSYS2 if you want the GCC / CMake toolchain helpers
- VS Code if you want the dedicated wrapper profile

The profile still loads if optional tools are missing; related sections will simply show reduced functionality.

## Installation

### Option 1 — Use this repository as your PowerShell profile directory

This is the simplest setup.

1. Find your profile directory:

```powershell
Split-Path $PROFILE -Parent
```

2. Clone this repository into that directory.

3. Start a new PowerShell session.

If the repository lives directly in your PowerShell profile directory, `Microsoft.PowerShell_profile.ps1` and `Microsoft.VSCode_profile.ps1` will be picked up automatically.

### Option 2 — Keep the repository elsewhere and symlink the profile files

If you want to keep the repo in a different folder, create symlinks from your PowerShell profile directory to:

- `Microsoft.PowerShell_profile.ps1`
- `Microsoft.VSCode_profile.ps1`

The profile resolves its config and theme paths relative to the script location, so symlinked entrypoints still work.

## Local configuration

Shared defaults live in `config.template.psd1`.

Machine-specific paths belong in `config.local.psd1`, which is ignored by Git.

Create it like this:

```powershell
Copy-Item .\config.template.psd1 .\config.local.psd1
```

Then edit `config.local.psd1` and keep only the values that are specific to your machine.

### Example `config.local.psd1`

```powershell
@{
    GoogleDrive = "D:\\YourDrive"
    Msys2Root   = "C:\\msys64"
}
```

Use only the keys you actually need on your machine. Leaving a key out is fine.

### Shared defaults currently come from `config.template.psd1`

- `OhMyPoshTheme`
- `UvGlobalVenv`
- `DevFolder`
- `DesktopFolder`
- `WorkspaceFolder`
- `OpenCodeConfigFolder`

## Oh My Posh theme behavior

The active theme lives at:

```text
theme/clean-detailed_custom.omp.json
```

Older snapshots live under:

```text
theme/archive/
```

Before Oh My Posh is initialized, the profile exports environment variables such as:

- `POSH_DESKTOP`
- `POSH_DOCUMENTS`
- `POSH_DOWNLOADS`
- `POSH_DEV`
- `POSH_WORKSPACE`
- `POSH_OPENCODE`
- `POSH_GOOGLEDRIVE`

The theme uses these values in `mapped_locations`, which keeps path icons dynamic without hardcoding one specific machine layout into the active theme.

## VS Code usage

`Microsoft.VSCode_profile.ps1` is a thin wrapper that dot-sources the main profile.

Use `.vscode/settings.template.json` as a reference if you want workspace-local VS Code settings for this repo. Your real `.vscode/settings.json` is intentionally ignored.

## Built-in commands

### Help

```powershell
phelp        # overview
phelp -d     # dev tool status
phelp -s     # shortcut paths
phelp -c     # profile command catalog
phelp -a     # expanded view
```

### Diagnostics

```powershell
Test-DevTools
Show-ShortcutPaths
Show-ProfileCommands
Show-StartupBanner -Force
```

### Python / uv

```powershell
Activate-UvGlobal
Deactivate-UvGlobal
Get-PythonExecutable
Get-PythonEnvInfo
Get-UvPythonExecutable
```

### MSYS2

```powershell
Show-Msys2Toolchain
Use-UCRT64
Use-MINGW64
Reset-Msys2Toolchain
```

## Repository layout

```text
.
├─ Microsoft.PowerShell_profile.ps1
├─ Microsoft.VSCode_profile.ps1
├─ README.md
├─ config.template.psd1
├─ config.local.psd1          # local only, ignored
├─ .gitignore
├─ theme/
│  ├─ clean-detailed_custom.omp.json
│  └─ archive/
├─ docs/
│  └─ PowerShell_Profile_Analysis.md
└─ .vscode/
   ├─ settings.template.json
   └─ settings.json           # local only, ignored
```

## Git / publishing model

This repository is designed so that:

- shared profile logic is tracked
- local machine paths stay in `config.local.psd1`
- local editor state stays in `.vscode/settings.json`
- theme history is preserved under `theme/archive/`

If you plan to publish your own fork publicly, review your local overrides and Git history before pushing.

If your existing local git history already contains personal paths, old local configs, or personal author metadata, the cleanest public-release path is usually to start with a fresh repository history after sanitizing the working tree.

## Notes

- This profile is Windows-first, but some parts are intentionally cross-platform.
- If `Oh My Posh`, `uv`, or MSYS2 are missing, the profile still loads; related commands become partial or informational.
- If you change local folder paths, restart your shell so the exported `POSH_*` variables and prompt mappings update together.
- For manual testing, open a fresh terminal instead of repeatedly dot-sourcing the profile during automation-heavy sessions.
