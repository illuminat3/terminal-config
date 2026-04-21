<#
.SYNOPSIS
    Provides contains-based tab completion for cd / Set-Location.
.DESCRIPTION
    Replaces the default starts-with tab completion with substring matching,
    so typing 'cd authority<Tab>' will find 'UK-ECOS-Authority'.
    Dot-source this file from your profile to activate it.
.EXAMPLE
    cd ecos<Tab>   # cycles through any folder containing 'ecos'
#>
Register-ArgumentCompleter -CommandName 'cd', 'Set-Location' -ParameterName 'Path' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $searchRoot = (Get-Location).Path

    Get-ChildItem -Path $searchRoot -Directory |
        Where-Object { $_.Name -like "*$wordToComplete*" } |
        Sort-Object Name |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_.FullName,
                $_.Name,
                'ProviderContainer',
                $_.FullName
            )
        }
}
