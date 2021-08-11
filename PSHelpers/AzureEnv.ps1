
$PSModulePath = $env:PSModulePath -split $PathSep
$AzModulePath = $MODULE_PATH -replace 'Modules$', 'AzModules'
if ($AzModulePath -notin $PSModulePath)
{
    $env:PSModulePath = $env:PSModulePath, $AzModulePath -join [System.IO.Path]::PathSeparator
}
