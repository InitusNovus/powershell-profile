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

    # WSL integration (Windows only)
    # WslDistro: distro name used in \\wsl$\<distro> path
    # WslUser: Linux username — set in config.local.psd1
    # WslDevFolder: subfolder under WSL home for $WDEV shortcut
    WslDistro     = "Ubuntu"
    WslUser       = $null
    WslDevFolder  = "dev"
}
