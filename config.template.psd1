@{
    # Prompt theme (relative to profile directory or absolute path)
    OhMyPoshTheme = "theme/clean-detailed_custom.omp.json"

    # uv global venv (relative to $HOME or absolute path)
    UvGlobalVenv  = "dev/_global-py/.venv"

    # Shared user folders
    DevFolder            = "dev"
    DesktopFolder        = "Desktop"
    WorkspaceFolder      = "Desktop\Workspace"
    OpenCodeConfigFolder = ".config\opencode"

    # WSL-only Linux-native workspace shortcut target
    # Keep as a literal path fragment/string; resolved at runtime when running inside WSL
    LwsFolder            = $null

    # Extra PATH entries for non-Windows (Linux/macOS)
    # Array of paths (relative to $HOME or absolute); prepended to $linuxPaths
    ExtraLinuxPaths = @()

    # WSL integration (Windows only)
    # WslDistro: distro name used in \\wsl$\<distro> path
    # WslUser: Linux username — set in config.local.psd1
    # WslDevFolder: subfolder under WSL home for $WDEV shortcut
    WslDistro     = "Ubuntu"
    WslUser       = $null
    WslDevFolder  = "dev"
}
