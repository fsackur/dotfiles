
$_HOME = 'C:\Users\mich8638'

$SourcePath = Join-Path $PSScriptRoot 'Code'
$DotFiles   = Get-ChildItem $SourcePath
$DotFiles   | ForEach-Object {
    cmd /c "mklink `"$_HOME\AppData\Roaming\Code\User\$($_.Name)`" `"$($_.FullName)`""
}

$SourcePath = Join-Path $PSScriptRoot 'Code - Insiders'
$DotFiles   = Get-ChildItem $SourcePath
$DotFiles   | ForEach-Object {
    cmd /c "mklink `"$_HOME\AppData\Roaming\Code - Insiders\User\$($_.Name)`" `"$($_.FullName)`""
}

$SourcePath = Join-Path $PSScriptRoot 'ConEmu'
$DotFiles   = Get-ChildItem $SourcePath
$DotFiles   | ForEach-Object {
    cmd /c "mklink `"$_HOME\AppData\Roaming\$($_.Name)`" `"$($_.FullName)`""
}
