Import-Module posh-git
oh-my-posh init pwsh --config (Join-Path $env:pwshConfig 'theme.omp.json') | Invoke-Expression

. (Join-Path $env:pwshConfig 'Open-Solution.ps1')
. (Join-Path $env:pwshConfig 'Fuzzy-Cd.ps1')

function git {
    if ($args[0] -eq 'cleanup') {
        & (Join-Path $env:pwshConfig 'git-cleanup.ps1') $args[1..($args.Length - 1)]
    } else {
        git.exe @args
    }
}
