$Options = $PSProfile.Settings.PSReadline.Options
if ($Options.Keys)
{
    Set-PSReadLineOption @Options
}
