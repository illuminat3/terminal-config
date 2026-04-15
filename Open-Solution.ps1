<#
.SYNOPSIS
    Provides Open-Solution and the 'vs' alias for launching Visual Studio 2026.

.DESCRIPTION
    Open-Solution searches the current directory for a .sln or .slnx file and
    opens it with devenv.exe (Visual Studio 2026 Professional).
    Dot-source this file from your profile to make the 'vs' alias available.

.EXAMPLE
    # From a project directory containing a solution file:
    vs
#>

function Open-Solution {
    $devenv = 'C:\Program Files\Microsoft Visual Studio\18\Professional\Common7\IDE\devenv.exe'
    $sln    = Get-ChildItem -Filter '*.sln*' |
              Where-Object { $_.Extension -in '.sln', '.slnx' } |
              Select-Object -First 1

    if (-not $sln) {
        Write-Warning 'No .sln or .slnx file found in current directory.'
        return
    }

    if (-not (Test-Path $devenv)) {
        Write-Warning "devenv.exe not found at: $devenv"
        return
    }

    Write-Host "Opening $($sln.Name)..."
    & $devenv $sln.FullName
}

Set-Alias vs Open-Solution
