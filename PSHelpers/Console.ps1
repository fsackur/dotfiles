
Set-PSReadLineOption -PredictionSource History
Set-PSReadlineKeyHandler -Chord Tab -Function TabCompleteNext
Set-PSReadlineKeyHandler -Chord Shift+Tab -Function TabCompletePrevious
# Set-PSReadlineKeyHandler -Chord Ctrl+Spacebar -Function MenuComplete      # https://github.com/microsoft/terminal/issues/2865
Set-PSReadlineKeyHandler -Chord Ctrl+p -Function MenuComplete
Set-PSReadLineKeyHandler -Chord Escape -Function CancelLine
Set-PSReadlineKeyHandler -Chord Ctrl+RightArrow -Function ForwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+LeftArrow -Function BackwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+LeftArrow -Function SelectBackwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+RightArrow -Function SelectForwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+End -Function SelectLine
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+Home -Function SelectBackwardsLine
Set-PSReadLineKeyHandler -Chord Ctrl-a -Function SelectAll
Set-PSReadlineKeyHandler -Chord Ctrl+c -Function CopyOrCancelLine         # https://github.com/PowerShell/PSReadLine/issues/1993
Set-PSReadlineKeyHandler -Chord Ctrl+x -Function Cut                      # https://github.com/PowerShell/PSReadLine/issues/1993
Set-PSReadlineKeyHandler -Chord Ctrl+z -Function Undo
Set-PSReadlineKeyHandler -Chord Ctrl+y -Function Redo


Set-PoshPrompt pure

Import-Module posh-git

$PSDefaultParameterValues += @{
    'Out-Default:OutVariable' = '+LastOutput'
}
