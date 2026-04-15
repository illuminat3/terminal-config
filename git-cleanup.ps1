<#
.SYNOPSIS
    Deletes local Git branches that are either merged or have no unique commits.

.DESCRIPTION
    Iterates over all local branches (excluding the current default branch and any
    protected/skipped names you specify) and removes them if they are:
      - Already merged into the default branch, OR
      - Unmerged but have zero commits that aren't in the default branch

    Branches with real unmerged work are left untouched.

.PARAMETER Skip
    One or more branch names to leave alone, regardless of their state.
    Wildcards are NOT supported — pass exact names.
    Example: -Skip feature/keep-me, release/2.0

.PARAMETER Default
    The branch to compare against when deciding what's merged / empty.
    Defaults to the repo's symbolic HEAD (main, master, develop, etc.).

.PARAMETER WhatIf
    Dry-run mode. Lists what would be deleted without actually deleting anything.

.EXAMPLE
    # Normal run — delete merged + empty branches
    git-cleanup

.EXAMPLE
    # Skip two branches and preview changes without deleting
    git-cleanup -Skip feature/wip, spike/perf -WhatIf

.EXAMPLE
    # Compare against a non-default base branch
    git-cleanup -Default develop -Skip release/next
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]] $Skip    = @(),
    [string]   $Default = '',
    [switch]   $WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DefaultBranch {
    # Try symbolic ref first (works when HEAD is not detached)
    $sym = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($sym) { return ($sym -replace 'refs/remotes/origin/', '') }

    # Fallback: look for common names that exist locally
    foreach ($candidate in 'main', 'master', 'develop', 'dev') {
        $exists = git rev-parse --verify $candidate 2>$null
        if ($exists) { return $candidate }
    }

    throw 'Could not determine the default branch. Pass -Default <branch> explicitly.'
}

function Write-Status([string]$Symbol, [string]$Color, [string]$Branch, [string]$Reason) {
    Write-Host "  $Symbol " -ForegroundColor $Color -NoNewline
    Write-Host $Branch -ForegroundColor White -NoNewline
    Write-Host "  $Reason" -ForegroundColor DarkGray
}

$null = git rev-parse --git-dir 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error 'Not inside a Git repository.'
    return
}

if (-not $Default) {
    $Default = Get-DefaultBranch
}

$null = git rev-parse --verify $Default 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Default branch '$Default' not found locally."
    return
}

# Always protect the default branch and current HEAD
$currentBranch = git rev-parse --abbrev-ref HEAD
$alwaysSkip    = @($Default, $currentBranch) | Select-Object -Unique

Write-Host ""
Write-Host "Git Branch Cleanup" -ForegroundColor Cyan
Write-Host "  Default branch : $Default" -ForegroundColor DarkGray
Write-Host "  Current HEAD   : $currentBranch" -ForegroundColor DarkGray
if ($Skip.Count -gt 0) {
    Write-Host "  Skipping       : $($Skip -join ', ')" -ForegroundColor DarkGray
}
if ($WhatIf) {
    Write-Host "  Mode           : DRY RUN (no branches will be deleted)" -ForegroundColor Yellow
}
Write-Host ""

$stats = @{ Deleted = 0; Skipped = 0; Kept = 0 }

# Get all local branches except HEAD indicator lines
$branches = git branch --format='%(refname:short)' | Where-Object { $_ -and $_ -notmatch '^\s*\*' }

foreach ($branch in $branches) {
    if ($branch -in $alwaysSkip) {
        Write-Status '○' 'DarkGray' $branch 'protected (default / HEAD)'
        $stats.Skipped++
        continue
    }

    if ($Skip -contains $branch) {
        Write-Status '○' 'DarkGray' $branch 'skipped (user request)'
        $stats.Skipped++
        continue
    }

    $mergedBranches = git branch --merged $Default --format='%(refname:short)'
    if ($branch -in $mergedBranches) {
        if ($WhatIf) {
            Write-Status '~' 'Yellow' $branch "would delete (merged into $Default)"
        } else {
            git branch -d $branch 2>&1 | Out-Null
            Write-Status '✓' 'Green' $branch "deleted (merged into $Default)"
        }
        $stats.Deleted++
        continue
    }

    $uniqueCommits = git log "$Default..$branch" --oneline 2>$null
    if (-not $uniqueCommits) {
        if ($WhatIf) {
            Write-Status '~' 'Yellow' $branch "would delete (no unique commits vs $Default)"
        } else {
            git branch -D $branch 2>&1 | Out-Null
            Write-Status '✓' 'Green' $branch "deleted (no unique commits vs $Default)"
        }
        $stats.Deleted++
        continue
    }

    $count = ($uniqueCommits | Measure-Object -Line).Lines
    Write-Status '·' 'DarkCyan' $branch "kept ($count unique commit$(if ($count -ne 1) {'s'}))"
    $stats.Kept++
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan -NoNewline
Write-Host "  Deleted: $($stats.Deleted)  Skipped: $($stats.Skipped)  Kept: $($stats.Kept)" -ForegroundColor DarkGray
Write-Host ""
