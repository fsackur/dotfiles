
$env:PSModulePath = $env:PSModulePath, ($MODULE_PATH -replace 'Modules$', 'AzModules') -join [System.IO.Path]::PathSeparator
