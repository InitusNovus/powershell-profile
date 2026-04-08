# ======================================================================
# VS Code Profile - Loads main PowerShell profile
# ======================================================================
# 메인 프로필을 그대로 로드하여 동일한 환경 제공
# VS Code 전용 설정이 필요하면 아래에 추가

$script:ProfileRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PROFILE }
$mainProfile = Join-Path $script:ProfileRoot "Microsoft.PowerShell_profile.ps1"

if (Test-Path -LiteralPath $mainProfile) {
    . $mainProfile
} else {
    Write-Warning "Main profile not found: $mainProfile"
    Write-Warning "VS Code terminal will have limited functionality."
}

# ======================================================================
# VS Code 전용 설정 (필요시 아래에 추가)
# ======================================================================
# 예: VS Code 전용 alias, 디버깅 헬퍼 등
# Set-Alias code-debug Start-VSCodeDebug