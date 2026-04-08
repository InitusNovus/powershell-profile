# ======================================================================
# PowerShell Profile (copy-paste 전체)
# ======================================================================

# --- macOS 전용 PATH 확장 (Windows에서 실행되지 않게) ---
# $env:PATH += ":/usr/local/share/dotnet:~/.dotnet/tools:/Library/Apple/usr/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/opt/homebrew/bin:$HOME/miniconda3/bin"
if (-not $IsWindows) {
  $env:PATH += ":/usr/local/share/dotnet:~/.dotnet/tools:/Library/Apple/usr/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/opt/homebrew/bin"
}

# ======================================================================
# ==== Profile config (template + local override) ====
# ======================================================================
$script:ProfileRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PROFILE }
$script:TemplateConfigPath = Join-Path $script:ProfileRoot "config.template.psd1"
$script:LocalConfigPath = Join-Path $script:ProfileRoot "config.local.psd1"

function Import-ProfileConfig {
  $defaults = @{
    OhMyPoshTheme = "theme/clean-detailed_custom.omp.json"
    UvGlobalVenv  = "dev/_global-py/.venv"
    DevFolder     = "dev"
    DesktopFolder = "Desktop"
    WorkspaceFolder = "Desktop\Workspace"
    OpenCodeConfigFolder = ".config\opencode"
    GoogleDrive   = $null
    Msys2Root     = $null
  }

  foreach ($path in @($script:TemplateConfigPath, $script:LocalConfigPath)) {
    if (Test-Path -LiteralPath $path) {
      try {
        $cfg = Import-PowerShellDataFile -LiteralPath $path
        if ($cfg) {
          foreach ($key in $cfg.Keys) {
            $defaults[$key] = $cfg[$key]
          }
        }
      } catch {
        Write-Warning "Failed to load config: $path - $($_.Exception.Message)"
      }
    }
  }

  return $defaults
}

function Resolve-ProfilePath {
  param([Parameter(Mandatory)][string]$PathOrName)
  if (Split-Path -Path $PathOrName -IsAbsolute) { return $PathOrName }
  return (Join-Path $script:ProfileRoot $PathOrName)
}

function Resolve-HomePath {
  param([Parameter(Mandatory)][string]$PathOrName)
  if (Split-Path -Path $PathOrName -IsAbsolute) { return $PathOrName }
  return (Join-Path $HOME $PathOrName)
}

function Resolve-UserFolderPath {
  param([Parameter(Mandatory)][ValidateSet("Desktop", "Documents", "Downloads")][string]$Name)

  if ($IsWindows) {
    switch ($Name) {
      "Desktop"   { return [Environment]::GetFolderPath("Desktop") }
      "Documents" { return [Environment]::GetFolderPath("MyDocuments") }
      "Downloads" { return (Join-Path $HOME "Downloads") }
    }
  }

  return (Join-Path $HOME $Name)
}

function Convert-ToPoshPath {
  param([string]$PathValue)
  if (-not $PathValue) { return $null }
  return ($PathValue -replace '\\', '/')
}

function Set-PoshPathEnv {
  param(
    [Parameter(Mandatory)][string]$Name,
    [string]$PathValue
  )

  $envName = "POSH_{0}" -f $Name.ToUpperInvariant()
  if ($PathValue) {
    Set-Item -Path ("Env:{0}" -f $envName) -Value (Convert-ToPoshPath $PathValue)
  } else {
    Remove-Item -Path ("Env:{0}" -f $envName) -ErrorAction SilentlyContinue
  }
}

$script:Config = Import-ProfileConfig

$script:DesktopPath = Resolve-UserFolderPath "Desktop"
$script:DocumentsPath = Resolve-UserFolderPath "Documents"
$script:DownloadsPath = Resolve-UserFolderPath "Downloads"
$script:DevPath = Resolve-HomePath $script:Config.DevFolder
$script:WorkspacePath = Resolve-HomePath $script:Config.WorkspaceFolder
$script:OpenCodePath = Resolve-HomePath $script:Config.OpenCodeConfigFolder
$script:GoogleDrivePath = if ($script:Config.GoogleDrive) { Resolve-HomePath $script:Config.GoogleDrive } else { $null }

Set-PoshPathEnv -Name "DESKTOP" -PathValue $script:DesktopPath
Set-PoshPathEnv -Name "DOCUMENTS" -PathValue $script:DocumentsPath
Set-PoshPathEnv -Name "DOWNLOADS" -PathValue $script:DownloadsPath
Set-PoshPathEnv -Name "DEV" -PathValue $script:DevPath
Set-PoshPathEnv -Name "WORKSPACE" -PathValue $script:WorkspacePath
Set-PoshPathEnv -Name "OPENCODE" -PathValue $script:OpenCodePath
Set-PoshPathEnv -Name "GOOGLEDRIVE" -PathValue $script:GoogleDrivePath

# --- oh-my-posh init ---
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
  $ompCfg = Resolve-ProfilePath $script:Config.OhMyPoshTheme
  if (Test-Path -LiteralPath $ompCfg) {
    oh-my-posh init pwsh --config $ompCfg  | Invoke-Expression
  } else {
    oh-my-posh init pwsh | Invoke-Expression
  }
  # VS Code Shell Integration 활성화 (명령 완료 감지용)
  if ($env:TERM_PROGRAM -eq "vscode") {
    $env:POSH_SHELL_INTEGRATION = $true
  }
}
# --- End ---


# $nanopb = "/usr/local/nanopb-0.4.8-macosx-x86/generator"

# ==== User folder shortcuts ====
$DESKTOP = $script:DesktopPath
$DEV = $script:DevPath
$WORKSPACE = $script:WorkspacePath
$WS = $WORKSPACE
$OPENCODE = $script:OpenCodePath
$OC = $OPENCODE
$GOOGLEDRIVE = $script:GoogleDrivePath
$GDRIVE = $GOOGLEDRIVE
$GD = $GOOGLEDRIVE

$script:ShortcutNames = @(
  "DESKTOP",
  "DEV",
  "GD",
  "GDRIVE",
  "GOOGLEDRIVE",
  "OC",
  "OPENCODE",
  "WORKSPACE",
  "WS"
)
# ==== end ====


# ======================================================================
# ==== Common PATH utilities ====
# ======================================================================

# 세션 시작 시 PATH baseline 저장(프로필이 여러 번 로드돼도 1회만)
if (-not $script:PATH_BASELINE) {
  $script:PATH_BASELINE = $env:Path
}

function Get-PathSep {
  [System.IO.Path]::PathSeparator
}

function Get-PathEntries {
  $sep = Get-PathSep
  $env:Path -split [regex]::Escape($sep) |
    Where-Object { $_ -and $_.Trim() -ne "" } |
    ForEach-Object { $_.Trim() }
}

function Normalize-PathEntry([string]$p) {
  if (-not $p) { return $null }
  # Windows/Unix 둘 다 대충 안정적으로 맞추기
  return $p.Trim().TrimEnd('\').TrimEnd('/')
}

function Set-PathEntries([string[]]$entries) {
  $sep = Get-PathSep
  $env:Path = ($entries | Where-Object { $_ -and $_.Trim() -ne "" }) -join $sep
}

function Remove-PathEntry {
<#!
.SYNOPSIS
Removes a path entry from the current session PATH (case-insensitive, normalized).

.DESCRIPTION
Normalizes path separators and trailing slashes, then removes matching entries
from PATH using PATH utilities (no direct string replace).

.PARAMETER PathToRemove
The path to remove (absolute or relative).

.EXAMPLE
Remove-PathEntry "C:\\Python39"

.NOTES
Session-scoped only; does not persist to system/user env.
#>
  param([Parameter(Mandatory)][string]$PathToRemove)

  $rm = Normalize-PathEntry $PathToRemove
  $entries = Get-PathEntries | Where-Object { (Normalize-PathEntry $_) -ine $rm }
  Set-PathEntries $entries
}

function Prepend-PathEntry {
<#!
.SYNOPSIS
Prepends a path entry to the current session PATH, removing duplicates first.

.DESCRIPTION
Normalizes separators, removes existing occurrences, and inserts at PATH front
to control command resolution priority.

.PARAMETER PathToPrepend
The path to place at the beginning of PATH.

.EXAMPLE
Prepend-PathEntry "C:\\msys64\\ucrt64\\bin"
#>
  param([Parameter(Mandatory)][string]$PathToPrepend)

  $pp = Normalize-PathEntry $PathToPrepend
  $entries = Get-PathEntries | Where-Object { (Normalize-PathEntry $_) -ine $pp }
  Set-PathEntries @($pp) + $entries
}

function Reset-Path {
  # 하드 리셋: 세션 시작 시점 PATH로 통째로 복귀
  $env:Path = $script:PATH_BASELINE
  Write-StatusMessage -Prefix "PATH" -Message "Restored to session baseline." -Kind Success
}

function Rebaseline-Path {
  # 지금 상태를 baseline으로 재설정
  $script:PATH_BASELINE = $env:Path
  Write-StatusMessage -Prefix "PATH" -Message "Baseline updated to current PATH." -Kind Success
}
# ==== end ====


# ======================================================================
# ==== uv Global venv helpers (cross-platform pwsh) ====
# ======================================================================

$Global:UvGlobalVenv = if (Split-Path -Path $script:Config.UvGlobalVenv -IsAbsolute) {
  $script:Config.UvGlobalVenv
} else {
  Join-Path $HOME $script:Config.UvGlobalVenv
}

function Get-VenvBinDir([string]$venvPath) {
    if ($IsWindows) { Join-Path $venvPath "Scripts" }
    else            { Join-Path $venvPath "bin" }
}

# !!! NOTE: Common PATH utilities의 Remove-PathEntry와 이름 충돌 나지 않게 uv 전용으로 분리 !!!
function Remove-PathEntryFromEnv([string]$entry) {
  if (-not $entry) { return }
  Remove-PathEntry $entry
}

<#!
.SYNOPSIS
Activates the configured uv global venv for this session.

.DESCRIPTION
Resolves the uv global venv path, prepends its bin/Scripts to PATH, and sets
VIRTUAL_ENV. If another venv is active, the function stops unless -Force is
supplied. Removes previous bin path to avoid duplication.

.PARAMETER Force
Override an existing VIRTUAL_ENV.

.EXAMPLE
Activate-UvGlobal

.EXAMPLE
Activate-UvGlobal -Force
#>
function Activate-UvGlobal {
  param([switch]$Force)

    $venv = (Resolve-Path -LiteralPath $Global:UvGlobalVenv -ErrorAction SilentlyContinue)?.Path
    if (-not $venv) {
        Write-Warning "Global venv not found: $Global:UvGlobalVenv`nCreate it: uv venv --python 3.12 `"$Global:UvGlobalVenv`""
        return
    }

    $bin = Get-VenvBinDir $venv
    if (-not (Test-Path -LiteralPath $bin)) {
        Write-Warning "Venv exists but bin dir not found: $bin"
        return
    }

    # 이미 다른 venv가 활성화된 경우 안전하게 중단 (명시적 -Force 필요)
    if ($env:VIRTUAL_ENV -and -not $Force) {
      Write-Warning "Another venv is active: $env:VIRTUAL_ENV"
      Write-Warning "Use -Force to override or deactivate first."
      return
    }

    # 이미 활성화돼 있으면 중복 추가 방지 + 경로 정리
    if ($env:VIRTUAL_ENV) {
      $oldBin = Get-VenvBinDir $env:VIRTUAL_ENV
      Remove-PathEntryFromEnv $oldBin
    }

    $env:VIRTUAL_ENV = $venv

    $sep = [System.IO.Path]::PathSeparator
    $pathParts = $env:PATH -split [regex]::Escape($sep) | ForEach-Object { $_.Trim() }
    if (-not ($pathParts -contains $bin)) {
        $env:PATH = "$bin$sep$env:PATH"
    }

    # 버전 출력(선택)
    $py = Join-Path $bin ($IsWindows ? "python.exe" : "python")
    try {
        $pyVer = & $py --version 2>$null
        if ($pyVer) { Write-StatusMessage -Prefix "uv" -Message ("Activated global venv → {0} ({1})" -f $env:VIRTUAL_ENV, $pyVer) -Kind Success }
        else        { Write-StatusMessage -Prefix "uv" -Message ("Activated global venv → {0}" -f $env:VIRTUAL_ENV) -Kind Success }
    } catch {
        Write-StatusMessage -Prefix "uv" -Message ("Activated global venv → {0}" -f $env:VIRTUAL_ENV) -Kind Success
    }
}

function Deactivate-UvGlobal {
    if ($env:VIRTUAL_ENV) {
        $bin = Get-VenvBinDir $env:VIRTUAL_ENV
        Remove-PathEntryFromEnv $bin
        Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
        Write-StatusMessage -Prefix "uv" -Message "Deactivated global venv." -Kind Success
    } else {
        Write-StatusMessage -Prefix "uv" -Message "No active venv (VIRTUAL_ENV not set)." -Kind Warning
    }
}

# alias는 함수 정의 이후에!
Set-Alias ga  Activate-UvGlobal
Set-Alias gde Deactivate-UvGlobal

# (선택) 자동 활성화
# Activate-UvGlobal
# ==== end ====


# ======================================================================
# ==== python helper ====
# ======================================================================

# (선택) 기본으로 차단하고 싶으면 주석 해제
# $env:UV_NO_MANAGED_PYTHON = "1"

# --- 내부 헬퍼: python 경로 가져오기 (Get-Command 기반, 빠름) ---
function Get-PythonPath {
  $py = Get-Command python -ErrorAction SilentlyContinue
  if ($py) { return $py.Source }
  return $null
}

# --- 내부 헬퍼: 안전한 명령 실행 ---
function Invoke-CommandSafely {
  param(
    [Parameter(Mandatory)][string]$Command,
    [string[]]$Arguments = @(),
    [string]$StripPrefix = ""
  )

  try {
    $result = & $Command @Arguments 2>$null
    if ($LASTEXITCODE -eq 0 -and $result) {
      $output = $result.Trim()
      if ($StripPrefix) { $output = $output.Replace($StripPrefix, "").Trim() }
      return $output
    }
  } catch { }
  return $null
}

# --- 내부 헬퍼: uv run python 경로 가져오기 ---
function Get-UvPythonPath {
  return Invoke-CommandSafely -Command "uv" -Arguments @("run", "python", "-c", "import sys; print(sys.executable)")
}

# --- 내부 헬퍼: venv 이름 가져오기 ---
function Get-VenvName {
<#!
.SYNOPSIS
Detects the current venv name from VIRTUAL_ENV or python executable path.

.DESCRIPTION
Returns the leaf folder of VIRTUAL_ENV when set. Otherwise inspects the active
python path to infer a venv pattern (Windows Scripts/python.exe or Unix
bin/python). Returns $null when not detected.

.EXAMPLE
Get-VenvName
#>
  # 1. VIRTUAL_ENV가 설정되어 있으면 우선 사용 (정식 activate 상태)
  if ($env:VIRTUAL_ENV) {
    return Split-Path $env:VIRTUAL_ENV -Leaf
  }
  
  # 2. 없으면 python 경로에서 venv 감지 (PATH만 설정된 상태)
  $pyPath = Get-PythonPath
  if ($pyPath) {
    # 크로스 플랫폼 정규식
    if ($IsWindows) {
      # C:\...\project_name\.venv\Scripts\python.exe → project_name
      if ($pyPath -match '\\([^\\]+)\\(\.?venv[^\\]*)\\Scripts\\python\.exe$') {
        return $matches[1]  # 상위 폴더명 (프로젝트명)
      }
    } else {
      # /home/user/project_name/.venv/bin/python → project_name
      if ($pyPath -match '/([^/]+)/(\.?venv[^/]*)/bin/python[^/]*$') {
        return $matches[1]  # 상위 폴더명 (프로젝트명)
      }
    }
  }
  
  return $null
}

# --- 내부 헬퍼: python 버전 정보 가져오기 ---
function Get-PythonVersion {
  return Invoke-CommandSafely -Command "python" -Arguments @("--version") -StripPrefix "Python "
}

function Get-UvPythonVersion {
  return Invoke-CommandSafely -Command "uv" -Arguments @("run", "python", "--version") -StripPrefix "Python "
}

# --- 사용자용 함수들 ---
function Get-PythonExecutable {
  # python 인터프리터에서 직접 확인 (더 정확하지만 느림)
  python -c "import sys; print(sys.executable)"
}

function Get-PythonEnvInfo {
  python -c "import sys; print('exe   =', sys.executable); print('prefix=', sys.prefix); print('base  =', getattr(sys, 'base_prefix', '')); print('venv  =', sys.prefix != getattr(sys, 'base_prefix', sys.prefix))"
}

function Get-UvPythonExecutable {
  uv run python -c "import sys; print(sys.executable)"
}

function Show-PythonEnvironmentBanner {
  $pyPath = Get-PythonPath
  $pyVersion = Get-PythonVersion
  $venvName = Get-VenvName
  
  # python 경로 + 버전
  if ($pyPath) {
    $displayValue = if ($pyVersion) { "$pyPath (v$pyVersion)" } else { $pyPath }
    Write-BannerLine -Header "[Python]" -Label "python" -Value $displayValue
  } else {
    Write-BannerLine -Header "[Python]" -Label "python" -Value "<not found>"
  }
  
  # venv 정보
  if ($env:VIRTUAL_ENV) {
    # 정식 activate된 경우 - 전체 경로 표시
    Write-BannerLine -Header "[Python]" -Label "venv" -Value "$venvName ($env:VIRTUAL_ENV)"
  } elseif ($venvName) {
    # 경로에서 감지된 경우 - detected 표시
    Write-BannerLine -Header "[Python]" -Label "venv" -Value "$venvName (path detected)"
  } else {
    Write-BannerLine -Header "[Python]" -Label "venv" -Value "<none>"
  }
}

# 기존 이름(가독성) + 짧은 이름(타이핑) 모두 alias로 유지
Set-Alias pywhere Get-PythonExecutable
Set-Alias pyw     Get-PythonExecutable

Set-Alias pyinfo  Get-PythonEnvInfo
Set-Alias pyi     Get-PythonEnvInfo

Set-Alias pyuvinfo Get-UvPythonExecutable
Set-Alias pyuv     Get-UvPythonExecutable
Set-Alias uvi      Get-UvPythonExecutable

Set-Alias pypath  Get-PythonPath
Set-Alias pyp     Get-PythonPath

# --- pip 경로 헬퍼 ---
function Get-PipPath {
  $pip = Get-Command pip -ErrorAction SilentlyContinue
  if ($pip) { return $pip.Source }
  return $null
}

function Get-UvPipPath {
  return Invoke-CommandSafely -Command "uv" -Arguments @("run", "pip", "--version") |
    ForEach-Object { if ($_ -match 'from\s+(.+)\s+\(') { $matches[1] } else { $null } }
}

function Get-PipExecutable {
  # pip 자체에서 경로 확인 (pip --version 출력에서 추출)
  $ver = pip --version 2>$null | Select-Object -First 1
  if ($ver -and $ver -match 'from\s+(.+)\s+\(') { return $matches[1] }
  return $null
}

function Get-UvPipExecutable {
  $ver = uv run pip --version 2>$null | Select-Object -First 1
  if ($ver -and $ver -match 'from\s+(.+)\s+\(') { return $matches[1] }
  return $null
}

Set-Alias pipwhere Get-PipExecutable
Set-Alias pipw     Get-PipExecutable

Set-Alias pipuv    Get-UvPipExecutable
Set-Alias uvpip    Get-UvPipExecutable

Set-Alias pippath  Get-PipPath
Set-Alias pipp     Get-PipPath

# ==== end ====
# ==== uv managed python policy toggles ====
# ======================================================================

function Get-UvManagedPythonPolicy {
  $val = (Get-Item Env:UV_NO_MANAGED_PYTHON -ErrorAction SilentlyContinue).Value
  if ($null -eq $val -or $val -eq "") {
    "[uv] managed python: ALLOWED"
  } else {
    "[uv] managed python: BLOCKED"
  }
}

function Show-UvEnvironmentBanner {
  # managed python 정책
  $val = (Get-Item Env:UV_NO_MANAGED_PYTHON -ErrorAction SilentlyContinue).Value
  if ($null -eq $val -or $val -eq "") {
    Write-BannerLine -Header "[uv]" -Label "managed" -Value "ALLOWED"
  } else {
    Write-BannerLine -Header "[uv]" -Label "managed" -Value "BLOCKED"
  }
  
  # uv run python 경로 + 버전
  $uvPyPath = Get-UvPythonPath
  $uvPyVersion = Get-UvPythonVersion
  if ($uvPyPath) {
    $displayValue = if ($uvPyVersion) { "$uvPyPath (v$uvPyVersion)" } else { $uvPyPath }
    Write-BannerLine -Header "[uv]" -Label "python" -Value $displayValue
  } else {
    Write-BannerLine -Header "[uv]" -Label "python" -Value "<not available>"
  }
}

function Enable-UvManagedPythonBlock {
  $env:UV_NO_MANAGED_PYTHON = "1"
  Get-UvManagedPythonPolicy
}

function Disable-UvManagedPythonBlock {
  Remove-Item Env:\UV_NO_MANAGED_PYTHON -ErrorAction SilentlyContinue
  Get-UvManagedPythonPolicy
}

function Invoke-UvWithManagedPython {
  param([Parameter(ValueFromRemainingArguments=$true)] $args)

  $old = (Get-Item Env:UV_NO_MANAGED_PYTHON -ErrorAction SilentlyContinue).Value
  Remove-Item Env:\UV_NO_MANAGED_PYTHON -ErrorAction SilentlyContinue

  try {
    uv @args
  } finally {
    if ($null -ne $old -and $old -ne "") {
      $env:UV_NO_MANAGED_PYTHON = $old
    } else {
      Remove-Item Env:\UV_NO_MANAGED_PYTHON -ErrorAction SilentlyContinue
    }
  }
}

# 기존 이름 + 짧은 이름 모두 alias로 유지
Set-Alias uvpolicy Get-UvManagedPythonPolicy
Set-Alias uvp      Get-UvManagedPythonPolicy

Set-Alias uvblock  Enable-UvManagedPythonBlock
Set-Alias uvb      Enable-UvManagedPythonBlock

Set-Alias uvallow  Disable-UvManagedPythonBlock
Set-Alias uva      Disable-UvManagedPythonBlock

Set-Alias uvm      Invoke-UvWithManagedPython

# ==== end ====


# ======================================================================
# ==== Dev tool diagnostics ====
# ======================================================================

function Get-StyleText {
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
    [string]$Foreground,
    [string]$Background,
    [switch]$Bold,
    [switch]$Italic,
    [switch]$Underline
  )

  if (-not $PSStyle) { return $Text }

  $prefix = ""
  if ($Foreground) { $prefix += $PSStyle.Foreground.$Foreground }
  if ($Background) { $prefix += $PSStyle.Background.$Background }
  if ($Bold) { $prefix += $PSStyle.Bold }
  if ($Italic) { $prefix += $PSStyle.Italic }
  if ($Underline) { $prefix += $PSStyle.Underline }

  if (-not $prefix) { return $Text }
  return "$prefix$Text$($PSStyle.Reset)"
}

function Write-StyledLine {
  param(
    [AllowEmptyString()][string]$Text = "",
    [string]$Foreground,
    [string]$Background,
    [switch]$Bold,
    [switch]$Italic,
    [switch]$Underline
  )

  Write-Host (Get-StyleText -Text $Text -Foreground $Foreground -Background $Background -Bold:$Bold -Italic:$Italic -Underline:$Underline)
}

function Write-SectionHeader {
  param([Parameter(Mandatory)][string]$Title)
  Write-StyledLine ""
  Write-StyledLine -Text ("=== {0} ===" -f $Title) -Foreground BrightCyan -Bold
}

function Write-SectionSeparator {
  Write-StyledLine -Text "----------------------------------------" -Foreground BrightBlack
}

function Write-DefinitionLine {
  param(
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Description,
    [int]$LabelWidth = 48
  )

  $paddedLabel = $Label.PadRight($LabelWidth)
  $labelText = Get-StyleText -Text ("- {0}" -f $paddedLabel) -Foreground BrightYellow -Bold
  $descriptionText = Get-StyleText -Text $Description -Foreground BrightWhite
  Write-Host "$labelText $descriptionText"
}

function Write-OptionLine {
  param(
    [Parameter(Mandatory)][string]$Flags,
    [Parameter(Mandatory)][string]$Description,
    [int]$FlagWidth = 28
  )

  $flagText = Get-StyleText -Text $Flags.PadRight($FlagWidth) -Foreground BrightYellow -Bold
  $descriptionText = Get-StyleText -Text $Description -Foreground BrightWhite
  Write-Host "  $flagText $descriptionText"
}

function Write-LabelValueLine {
  param(
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Value
  )

  $labelText = Get-StyleText -Text ("[{0}]" -f $Label) -Foreground BrightYellow -Bold
  $valueText = Get-StyleText -Text $Value -Foreground BrightWhite
  Write-Host "$labelText $valueText"
}

function Write-StatusMessage {
  param(
    [Parameter(Mandatory)][string]$Prefix,
    [Parameter(Mandatory)][string]$Message,
    [ValidateSet("Success", "Info", "Warning", "Error")][string]$Kind = "Info"
  )

  $prefixColor = switch ($Kind) {
    "Success" { "BrightGreen" }
    "Warning" { "BrightYellow" }
    "Error"   { "BrightRed" }
    default    { "BrightCyan" }
  }

  $messageColor = switch ($Kind) {
    "Success" { "BrightWhite" }
    "Warning" { "BrightWhite" }
    "Error"   { "BrightWhite" }
    default    { "BrightWhite" }
  }

  $prefixText = Get-StyleText -Text ("[{0}]" -f $Prefix) -Foreground $prefixColor -Bold
  $messageText = Get-StyleText -Text $Message -Foreground $messageColor
  Write-Host "$prefixText $messageText"
}

function Write-ToolValueLine {
  param(
    [Parameter(Mandatory)][string]$Name,
    [string]$Value,
    [string]$MissingText = "<none>"
  )

  $nameText = Get-StyleText -Text ("  {0,-6}:" -f $Name) -Foreground BrightYellow -Bold
  if ($Value) {
    $valueText = Get-StyleText -Text $Value -Foreground BrightWhite
  } else {
    $valueText = Get-StyleText -Text $MissingText -Foreground BrightRed -Italic
  }
  Write-Host "$nameText $valueText"
}

function Show-CommandStatus {
  param(
    [Parameter(Mandatory)][string]$Name,
    [scriptblock]$VersionScript
  )

  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    $nameText = Get-StyleText -Text ("[{0}]" -f $Name) -Foreground BrightRed -Bold
    $valueText = Get-StyleText -Text "<not found>" -Foreground DarkGray -Italic
    Write-Host "$nameText $valueText"
    return
  }

  $version = $null
  if ($VersionScript) {
    try {
      $version = & $VersionScript
    } catch {
      $version = $null
    }
  }

  if ($version) {
    $nameText = Get-StyleText -Text ("[{0}]" -f $Name) -Foreground BrightGreen -Bold
    $pathText = Get-StyleText -Text $cmd.Source -Foreground BrightCyan
    $versionText = Get-StyleText -Text ("({0})" -f $version) -Foreground BrightBlack -Italic
    Write-Host "$nameText $pathText $versionText"
  } else {
    $nameText = Get-StyleText -Text ("[{0}]" -f $Name) -Foreground BrightGreen -Bold
    $pathText = Get-StyleText -Text $cmd.Source -Foreground BrightCyan
    Write-Host "$nameText $pathText"
  }
}

function Get-ShortcutDisplayEntries {
  $shortcutGroups = @{}

  foreach ($name in ($script:ShortcutNames | Sort-Object)) {
    $value = Get-Variable -Name $name -ValueOnly -ErrorAction SilentlyContinue
    if ($value) {
      if (-not $shortcutGroups.ContainsKey($value)) {
        $shortcutGroups[$value] = @()
      }
      $shortcutGroups[$value] += $name
    }
  }

  $shortcutGroups.GetEnumerator() |
    ForEach-Object {
      $names = $_.Value | Sort-Object @{ Expression = { $_.Length }; Descending = $true }, @{ Expression = { $_ }; Descending = $false }
      [pscustomobject]@{
        Label = ($names -join '; ')
        SortKey = $names[0]
        Value = $_.Key
      }
    } |
    Sort-Object SortKey
}

function Test-DevTools {
  Write-SectionHeader "Dev tool status"

  Show-CommandStatus -Name "oh-my-posh" -VersionScript { (& oh-my-posh version 2>$null | Select-Object -First 1) }
  Show-CommandStatus -Name "git" -VersionScript { (& git --version 2>$null | Select-Object -First 1) }
  Show-CommandStatus -Name "python" -VersionScript { $v = Get-PythonVersion; if ($v) { "Python $v" } }
  Show-CommandStatus -Name "pip" -VersionScript { (& pip --version 2>$null | Select-Object -First 1) }
  Show-CommandStatus -Name "uv" -VersionScript { (& uv --version 2>$null | Select-Object -First 1) }
  Show-CommandStatus -Name "gcc" -VersionScript { (& gcc --version 2>$null | Select-Object -First 1) }
  Show-CommandStatus -Name "g++" -VersionScript { (& g++ --version 2>$null | Select-Object -First 1) }
  Show-CommandStatus -Name "cmake" -VersionScript { (& cmake --version 2>$null | Select-Object -First 1) }
  Show-CommandStatus -Name "ninja" -VersionScript { (& ninja --version 2>$null | Select-Object -First 1) }
}

function Show-ShortcutPaths {
  Write-SectionHeader "Shortcut paths"
  Get-ShortcutDisplayEntries | ForEach-Object {
    Write-LabelValueLine -Label $_.Label -Value $_.Value
  }
}

function Show-ProfileCommands {
  Write-SectionHeader "Profile commands"

  $catalog = [ordered]@{
    "Diagnostics" = @(
      @{ Name = "Test-DevTools"; Aliases = @(); Description = "Show external tool paths and versions" }
      @{ Name = "Show-ShortcutPaths"; Aliases = @(); Description = "Show user-defined shortcut paths" }
      @{ Name = "Show-ProfileCommands"; Aliases = @(); Description = "List profile commands by category" }
      @{ Name = "Show-ProfileHelp"; Aliases = @("profilehelp", "phelp", "ph"); Description = "Show the top-level profile help overview" }
    )
    "PATH" = @(
      @{ Name = "Remove-PathEntry"; Aliases = @(); Description = "Remove a path entry from current PATH" }
      @{ Name = "Prepend-PathEntry"; Aliases = @(); Description = "Move a path entry to the front of PATH" }
      @{ Name = "Reset-Path"; Aliases = @(); Description = "Restore PATH to the session baseline" }
      @{ Name = "Rebaseline-Path"; Aliases = @(); Description = "Update PATH baseline to current PATH" }
    )
    "Python / uv" = @(
      @{ Name = "Activate-UvGlobal"; Aliases = @("ga"); Description = "Activate the configured uv global venv" }
      @{ Name = "Deactivate-UvGlobal"; Aliases = @("gde"); Description = "Deactivate the current uv global venv" }
      @{ Name = "Get-PythonExecutable"; Aliases = @("pywhere", "pyw"); Description = "Show the active python executable path" }
      @{ Name = "Get-PythonEnvInfo"; Aliases = @("pyinfo", "pyi"); Description = "Show detailed python environment info" }
      @{ Name = "Get-UvPythonExecutable"; Aliases = @("pyuvinfo", "pyuv", "uvi"); Description = "Show uv-managed python executable path" }
      @{ Name = "Get-PythonPath"; Aliases = @("pypath", "pyp"); Description = "Resolve python from PATH" }
      @{ Name = "Get-PipExecutable"; Aliases = @("pipwhere", "pipw"); Description = "Show the active pip executable path" }
      @{ Name = "Get-UvPipExecutable"; Aliases = @("pipuv", "uvpip"); Description = "Show uv-managed pip path" }
      @{ Name = "Get-PipPath"; Aliases = @("pippath", "pipp"); Description = "Resolve pip from PATH" }
      @{ Name = "Get-UvManagedPythonPolicy"; Aliases = @("uvpolicy", "uvp"); Description = "Show uv managed-python policy" }
      @{ Name = "Enable-UvManagedPythonBlock"; Aliases = @("uvblock", "uvb"); Description = "Block uv managed Python for this session" }
      @{ Name = "Disable-UvManagedPythonBlock"; Aliases = @("uvallow", "uva"); Description = "Allow uv managed Python for this session" }
      @{ Name = "Invoke-UvWithManagedPython"; Aliases = @("uvm"); Description = "Run uv with managed Python temporarily enabled" }
    )
    "MSYS2" = @(
      @{ Name = "Show-Msys2Toolchain"; Aliases = @(); Description = "Show current MSYS2 toolchain resolution" }
      @{ Name = "Use-UCRT64"; Aliases = @(); Description = "Prefer the UCRT64 MSYS2 toolchain" }
      @{ Name = "Use-MINGW64"; Aliases = @(); Description = "Prefer the MINGW64 MSYS2 toolchain" }
      @{ Name = "Reset-Msys2Toolchain"; Aliases = @(); Description = "Reset MSYS2 preference back to UCRT64" }
    )
    "UI / Banner" = @(
      @{ Name = "Show-StartupBanner"; Aliases = @(); Description = "Render the profile startup banner again" }
    )
    "Other" = @(
      @{ Name = "Build-nanopb"; Aliases = @(); Description = "Run the nanopb generator with python" }
    )
  }

  foreach ($category in $catalog.Keys) {
    Write-SectionHeader $category
    foreach ($entry in $catalog[$category]) {
      $label = if ($entry.Aliases.Count -gt 0) {
        "{0} ({1})" -f $entry.Name, ($entry.Aliases -join ", ")
      } else {
        $entry.Name
      }
      Write-DefinitionLine -Label $label -Description $entry.Description
    }
  }
}

function Show-ProfileHelp {
  param(
    [Alias("d", "dt")][switch]$DevTools,
    [Alias("s", "sc")][switch]$Shortcuts,
    [Alias("c", "pc")][switch]$ProfileCommands,
    [Alias("a")][switch]$All,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$ExtraArgs
  )

  foreach ($arg in $ExtraArgs) {
    switch ($arg.ToLowerInvariant()) {
      "--devtools" { $DevTools = $true; continue }
      "--shortcuts" { $Shortcuts = $true; continue }
      "--profilecommands" { $ProfileCommands = $true; continue }
      "--commands" { $ProfileCommands = $true; continue }
      "--all" { $All = $true; continue }
      default { Write-Warning "Unknown phelp option: $arg" }
    }
  }

  if ($All) {
    $DevTools = $true
    $Shortcuts = $true
    $ProfileCommands = $true
  }

  if ($DevTools -or $Shortcuts -or $ProfileCommands) {
    if ($All) {
      Write-SectionHeader "Profile help (expanded)"
      Write-StyledLine -Text ("Selections: devtools={0}, shortcuts={1}, commands={2}" -f $DevTools, $Shortcuts, $ProfileCommands) -Foreground BrightBlack -Italic
      Write-SectionSeparator
    }

    if ($DevTools) { Test-DevTools }
    if ($Shortcuts) {
      if ($DevTools) { Write-SectionSeparator }
      Show-ShortcutPaths
    }
    if ($ProfileCommands) {
      if ($DevTools -or $Shortcuts) { Write-SectionSeparator }
      Show-ProfileCommands
    }
    return
  }

  Write-SectionHeader "PowerShell profile help"
  Write-StyledLine -Text "Usage:" -Foreground BrightYellow -Bold
  Write-StyledLine -Text "  phelp [ -d | -s | -c | -a ]" -Foreground BrightWhite
  Write-StyledLine -Text "  phelp [ --devtools | --shortcuts | --profilecommands | --all ]" -Foreground BrightWhite
  Write-StyledLine ""
  Write-StyledLine -Text "Options:" -Foreground BrightYellow -Bold
  Write-OptionLine -Flags "-d, --devtools" -Description "Show external tool paths and versions"
  Write-OptionLine -Flags "-s, --shortcuts" -Description "Show user-defined shortcut paths (grouped)"
  Write-OptionLine -Flags "-c, --profilecommands" -Description "Show the profile command catalog by category"
  Write-OptionLine -Flags "-a, --all" -Description "Show all three sections in one expanded view"
  Write-StyledLine ""
  Write-StyledLine -Text "Example:" -Foreground BrightYellow -Bold
  Write-StyledLine -Text "  phelp -a" -Foreground BrightYellow -Bold
  Write-StyledLine ""
  Write-StyledLine -Text "Verbose commands:" -Foreground BrightYellow -Bold
  Write-StyledLine -Text "  Test-DevTools, Show-ShortcutPaths, Show-ProfileCommands" -Foreground BrightBlack -Italic
}

Set-Alias profilehelp Show-ProfileHelp
Set-Alias phelp       Show-ProfileHelp
Set-Alias ph          Show-ProfileHelp

# ==== end ====


# ======================================================================
# ==== nanopb helper ====
# ======================================================================
function Build-nanopb {
  param(
    [string]$protofile
  )
  & python $nanopb/nanopb_generator $protofile
}
# ==== end ====


# ======================================================================
# ==== macOS 전용 유틸 함수 (필요시 주석 해제) ====
# ======================================================================

# For opening files in TextEdit on macOS
# function textedit {
#   param(
#     [string]$file
#   )
#
#   if (-not $file) {
#     Write-Error "No file path provided. Please provide a valid file path."
#     return
#   }
#
#   & open -a TextEdit $file
# }

# ==== end ====


# ======================================================================
# ==== MSYS2 toolchain status helpers (Windows-only 성격) ====
# ======================================================================

$global:MSYS2_ROOT = if ($script:Config.Msys2Root) { $script:Config.Msys2Root } else { $null }
$global:MSYS2_UCRT_BIN  = if ($global:MSYS2_ROOT) { Join-Path $global:MSYS2_ROOT "ucrt64\bin" } else { $null }
$global:MSYS2_MINGW_BIN = if ($global:MSYS2_ROOT) { Join-Path $global:MSYS2_ROOT "mingw64\bin" } else { $null }

function Get-PathIndex {
  param([Parameter(Mandatory)] [string] $needle)
  $needleNorm = $needle.Trim().TrimEnd('\')
  $i = 0
  $sep = Get-PathSep
  foreach ($p in $env:Path.Split($sep)) {
    if ($p) {
      $pNorm = $p.Trim().TrimEnd('\')
      if ($pNorm -ieq $needleNorm) { return $i }
    }
    $i++
  }
  return [int]::MaxValue
}

function Get-Msys2Preference {
  if (-not $global:MSYS2_UCRT_BIN -or -not $global:MSYS2_MINGW_BIN) { return "not-configured" }
  $iu = Get-PathIndex $global:MSYS2_UCRT_BIN
  $im = Get-PathIndex $global:MSYS2_MINGW_BIN

  if ($iu -eq [int]::MaxValue -and $im -eq [int]::MaxValue) { return "none" }
  if ($iu -lt $im) { return "UCRT64" }
  if ($im -lt $iu) { return "MINGW64" }
  return "both"
}

function Get-ActiveMsys2Toolchain {
  $gcc = Get-Command gcc -ErrorAction SilentlyContinue
  if (-not $gcc) { return "none" }

  $src = $gcc.Source
  if ($src -like "$($global:MSYS2_UCRT_BIN)\*")  { return "UCRT64" }
  if ($src -like "$($global:MSYS2_MINGW_BIN)\*") { return "MINGW64" }
  return "other"
}

function Show-Msys2Toolchain {
  if (-not $global:MSYS2_ROOT) {
    Write-SectionHeader "MSYS2 toolchain"
    Write-StatusMessage -Prefix "MSYS2" -Message "Msys2Root is not configured. Set it in config.local.psd1 on this machine." -Kind Warning
    return
  }

  $pref = Get-Msys2Preference
  $act  = Get-ActiveMsys2Toolchain

  $cmake = (Get-Command cmake -ErrorAction SilentlyContinue)?.Source
  $gcc   = (Get-Command gcc  -ErrorAction SilentlyContinue)?.Source
  $gpp   = (Get-Command g++  -ErrorAction SilentlyContinue)?.Source

  $make  = (Get-Command mingw32-make -ErrorAction SilentlyContinue)?.Source
  if (-not $make) { $make = (Get-Command make -ErrorAction SilentlyContinue)?.Source }

  $ninja = (Get-Command ninja -ErrorAction SilentlyContinue)?.Source

  Write-SectionHeader "MSYS2 toolchain"

  $prefixText = Get-StyleText -Text "[MSYS2]" -Foreground BrightCyan -Bold
  $prefLabel = Get-StyleText -Text "preferred=" -Foreground BrightYellow -Bold
  $prefValue = Get-StyleText -Text $pref -Foreground BrightWhite
  $actLabel = Get-StyleText -Text "active=" -Foreground BrightYellow -Bold
  $actValueColor = if ($act -eq "none" -or $act -eq "other") { "BrightRed" } else { "BrightGreen" }
  $actValue = Get-StyleText -Text $act -Foreground $actValueColor -Bold
  Write-Host "$prefixText $prefLabel$prefValue | $actLabel$actValue"

  Write-ToolValueLine -Name "cmake" -Value $cmake
  Write-ToolValueLine -Name "gcc" -Value $gcc
  Write-ToolValueLine -Name "g++" -Value $gpp

  Write-ToolValueLine -Name "make" -Value $make
  Write-ToolValueLine -Name "ninja" -Value $ninja

  $iu = Get-PathIndex $global:MSYS2_UCRT_BIN
  $im = Get-PathIndex $global:MSYS2_MINGW_BIN
  $iuTxt = if ($iu -eq [int]::MaxValue) { "not-in-path" } else { $iu }
  $imTxt = if ($im -eq [int]::MaxValue) { "not-in-path" } else { $im }
  $pathLabel = Get-StyleText -Text "  PATH order:" -Foreground BrightYellow -Bold
  $pathValue = Get-StyleText -Text ("ucrt64[{0}] vs mingw64[{1}]" -f $iuTxt, $imTxt) -Foreground BrightWhite
  Write-Host "$pathLabel $pathValue"

  if ($env:CC -or $env:CXX) {
    $ccLabel = Get-StyleText -Text "  CC/CXX:" -Foreground BrightYellow -Bold
    $ccValue = Get-StyleText -Text ("{0} / {1}" -f ($env:CC ?? "<unset>"), ($env:CXX ?? "<unset>")) -Foreground BrightWhite
    Write-Host "$ccLabel $ccValue"
  }
}

function Show-Msys2ToolchainBanner {
  if (-not $global:MSYS2_ROOT) {
    Write-BannerLine -Header "[MSYS2]" -Label "status" -Value "not configured"
    return
  }

  $pref = Get-Msys2Preference
  $act  = Get-ActiveMsys2Toolchain

  $iu = Get-PathIndex $global:MSYS2_UCRT_BIN
  $im = Get-PathIndex $global:MSYS2_MINGW_BIN
  $iuTxt = if ($iu -eq [int]::MaxValue) { "not-in-path" } else { $iu }
  $imTxt = if ($im -eq [int]::MaxValue) { "not-in-path" } else { $im }

  Write-BannerLine -Header "[MSYS2]" -Label "status" -Value ("preferred={0} | active={1} | ucrt64[{2}] mingw64[{3}]" -f $pref, $act, $iuTxt, $imTxt)
}

function Set-Msys2PreferredPath {
  param([Parameter(Mandatory)][ValidateSet("UCRT64","MINGW64")] [string]$Which)

  if (-not $global:MSYS2_ROOT) {
    Write-StatusMessage -Prefix "MSYS2" -Message "Msys2Root is not configured for this machine." -Kind Warning
    return
  }

  # 먼저 둘 다 제거(중복/꼬임 방지)
  Remove-PathEntry $global:MSYS2_UCRT_BIN
  Remove-PathEntry $global:MSYS2_MINGW_BIN

  # 원하는 것만 맨 앞으로
  if ($Which -eq "UCRT64") { Prepend-PathEntry $global:MSYS2_UCRT_BIN }
  else { Prepend-PathEntry $global:MSYS2_MINGW_BIN }
}

function Use-UCRT64 {
  Set-Msys2PreferredPath UCRT64
  Remove-Item Env:CC  -ErrorAction SilentlyContinue
  Remove-Item Env:CXX -ErrorAction SilentlyContinue
  Write-StatusMessage -Prefix "MSYS2" -Message ("PATH now preferring: {0}" -f $global:MSYS2_UCRT_BIN) -Kind Success
}

function Use-MINGW64 {
  Set-Msys2PreferredPath MINGW64
  $env:CC  = "gcc"
  $env:CXX = "g++"
  Write-StatusMessage -Prefix "MSYS2" -Message ("PATH now preferring: {0}" -f $global:MSYS2_MINGW_BIN) -Kind Success
}

function Reset-Msys2Toolchain {
  # soft reset: “MSYS2 쪽 우선순위만” 기본(UCRT64 선호)으로 정리
  # (PATH 전체 reset은 Reset-Path를 쓰는 걸로 역할 분리)
  Use-UCRT64
  Write-StatusMessage -Prefix "MSYS2" -Message "Toolchain reset (soft): prefer UCRT64." -Kind Info
}
# ==== end ====



# ======================================================================
# ==== Startup banner (header/footer, console-width aware) ====
# ======================================================================

if (-not $script:STARTUP_BANNER_SHOWN) { $script:STARTUP_BANNER_SHOWN = $false }

function Get-ConsoleWidthSafe {
  param([int]$Fallback = 74)
  try {
    $w = [Console]::WindowWidth
    if ($w -lt 40) { return $Fallback }
    return ($w - 1)  # 오른쪽 끝 줄바꿈 방지
  } catch {
    return $Fallback
  }
}

# --- 배너 출력용 헬퍼: 터미널 폭에 맞춰 truncate ---
function Write-BannerLine {
  param(
    [string]$Header,   # "[Python]", "[uv]" 등
    [string]$Label,    # "python", "venv" 등
    [string]$Value,    # 실제 값
    [int]$LabelWidth = 8  # 라벨 정렬 폭
  )
  $w = Get-ConsoleWidthSafe
  $paddedLabel = $Label.PadRight($LabelWidth)
  $prefix = "{0} {1}: " -f $Header, $paddedLabel
  $available = $w - $prefix.Length
  
  if ($Value.Length -gt $available -and $available -gt 10) {
    $truncated = $Value.Substring($Value.Length - $available + 3)
    
    # 경로 구분자에서 깔끔하게 자르기
    if ($truncated[0] -notin @('\', '/')) {
      # 첫 글자가 구분자가 아니면, 다음 구분자까지 더 자르기
      $nextSep = -1
      for ($i = 1; $i -lt $truncated.Length; $i++) {
        if ($truncated[$i] -in @('\', '/')) {
          $nextSep = $i
          break
        }
      }
      if ($nextSep -gt 0) {
        $truncated = $truncated.Substring($nextSep)
      }
    }
    
    $Value = "..." + $truncated
  }

  $headerText = Get-StyleText -Text $Header -Foreground BrightCyan -Bold
  $labelText = Get-StyleText -Text $paddedLabel -Foreground BrightYellow -Bold
  $valueColor = switch -Regex ($Value) {
    "^(ALLOWED|UCRT64|MINGW64)(\b|\s|$)" { "BrightGreen"; break }
    "^(BLOCKED|none|other|<not found>|<not available>|<none>)(\b|\s|$)" { "BrightRed"; break }
    default { "BrightWhite" }
  }
  $valueItalic = ($Value -match '^<.+>$')
  $valueText = Get-StyleText -Text $Value -Foreground $valueColor -Italic:$valueItalic
  Write-Host "$headerText $labelText`: $valueText"
}

function Write-StartupHeader {
  param([string]$Title = "PowerShell profile")
  $w = Get-ConsoleWidthSafe
  $lineTop = ("=" * $w)
  $lineMid = ("-" * $w)
  $titleText = Get-StyleText -Text ("[{0}]" -f $Title) -Foreground BrightCyan -Bold
  $timeText = Get-StyleText -Text (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") -Foreground BrightWhite
  Write-StyledLine -Text $lineTop -Foreground BrightBlack
  Write-Host "$titleText $timeText"
  Write-StyledLine -Text $lineMid -Foreground BrightBlack
}

function Write-StartupFooter {
  $w = Get-ConsoleWidthSafe
  $lineBot = ("=" * $w)
  Write-StyledLine -Text $lineBot -Foreground BrightBlack
  Write-StyledLine ""
}

function Show-StartupBanner {
<#!
.SYNOPSIS
Displays the startup banner with Python, uv, and MSYS2 status.

.DESCRIPTION
Prints a width-aware header/footer and calls the banner functions that report
Python environment, uv managed status, and MSYS2 toolchain preference.

.PARAMETER Force
Force banner display even if already shown in this session.

.EXAMPLE
Show-StartupBanner -Force
#>
  param([switch]$Force)

  if (-not $Force -and $script:STARTUP_BANNER_SHOWN) { return }
  $script:STARTUP_BANNER_SHOWN = $true

  Write-StartupHeader

  # === 시작 시 출력 항목 모음(여기만 만지면 됨) ===
  # Write-Host ("PowerShell {0}" -f $PSVersionTable.PSVersion.ToString())

  if (Get-Command Show-PythonEnvironmentBanner -ErrorAction SilentlyContinue) {
    Show-PythonEnvironmentBanner
  }

  if (Get-Command Show-UvEnvironmentBanner -ErrorAction SilentlyContinue) {
    Show-UvEnvironmentBanner
  }

  if (Get-Command Show-Msys2ToolchainBanner -ErrorAction SilentlyContinue) {
    Show-Msys2ToolchainBanner
  }

  Write-BannerLine -Header "[Help]" -Label "phelp" -Value "phelp (use -a for all; -d/-s/-c for sections)"

  Write-StartupFooter
}
# ==== end ====


# ======================================================================
# ==== Start (한 번만 호출) ====
# ======================================================================
Show-StartupBanner
