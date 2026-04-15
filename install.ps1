#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the terminal-config profile into $HOME\pwsh\scripts\terminal-config.

.DESCRIPTION
    1. Creates $HOME\pwsh\scripts if it doesn't exist.
    2. Clones (or pulls) the terminal-config repository there.
    3. Sets the User-scoped $env:pwshConfig environment variable to the repo path.
    4. Bootstraps the real PowerShell $PROFILE to dot-source the repo's profile.

.PARAMETER RepoUrl
    Git URL of the repository to clone.
    Defaults to https://github.com/illuminat3/terminal-config.git

.PARAMETER Force
    Remove and re-clone an existing installation instead of pulling.

.EXAMPLE
    # First-time install
    .\install.ps1

.EXAMPLE
    # Force a clean re-clone
    .\install.ps1 -Force
#>
param(
    [string] $RepoUrl = 'https://github.com/illuminat3/terminal-config.git',
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$scriptsRoot = Join-Path $HOME 'pwsh\scripts'
$repoPath    = Join-Path $scriptsRoot 'terminal-config'

# ---------------------------------------------------------------------------
# 1. Ensure scripts directory exists
# ---------------------------------------------------------------------------
if (-not (Test-Path $scriptsRoot)) {
    New-Item -ItemType Directory -Path $scriptsRoot -Force | Out-Null
    Write-Host "Created : $scriptsRoot" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. Clone or update the repository
# ---------------------------------------------------------------------------
if (Test-Path (Join-Path $repoPath '.git')) {
    if ($Force) {
        Write-Host 'Removing existing installation...' -ForegroundColor Yellow
        Remove-Item -Recurse -Force $repoPath
    } else {
        Write-Host "Repository already present at: $repoPath" -ForegroundColor Cyan
        Write-Host 'Pulling latest changes...' -ForegroundColor Cyan
        git -C $repoPath pull origin main
    }
}

if (-not (Test-Path (Join-Path $repoPath '.git'))) {
    Write-Host "Cloning $RepoUrl -> $repoPath ..." -ForegroundColor Cyan
    git clone $RepoUrl $repoPath
}

# ---------------------------------------------------------------------------
# 3. Persist $pwshConfig as a User environment variable
# ---------------------------------------------------------------------------
[System.Environment]::SetEnvironmentVariable('pwshConfig', $repoPath, 'User')
$env:pwshConfig = $repoPath
Write-Host "Set     : `$env:pwshConfig = $repoPath" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Bootstrap the real $PROFILE to dot-source the repo's profile
# ---------------------------------------------------------------------------
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Single-quoted here-string: nothing is expanded — the literals $env:pwshConfig
# and '$Profile' appear verbatim in the generated file, which is exactly what
# we want so they evaluate at shell startup, not at install time.
$bootstrap = @'
# Terminal config — managed by install.ps1
$env:pwshConfig = [System.Environment]::GetEnvironmentVariable('pwshConfig', 'User')
. (Join-Path $env:pwshConfig '$Profile')
'@

if (Test-Path $PROFILE) {
    $existing = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($existing -match '# Terminal config') {
        Write-Host "Profile : already bootstrapped — $PROFILE" -ForegroundColor Cyan
    } else {
        Add-Content -Path $PROFILE -Value "`n$bootstrap"
        Write-Host "Updated : $PROFILE" -ForegroundColor Green
    }
} else {
    Set-Content -Path $PROFILE -Value $bootstrap
    Write-Host "Created : $PROFILE" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Installation complete.' -ForegroundColor Green
Write-Host "  Repo    : $repoPath"  -ForegroundColor DarkGray
Write-Host "  Profile : $PROFILE"   -ForegroundColor DarkGray
Write-Host ''
Write-Host 'Restart PowerShell or run:  . $PROFILE' -ForegroundColor Yellow
