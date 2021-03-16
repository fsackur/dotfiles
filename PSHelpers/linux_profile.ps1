
$env:TOKX_USE_RSA = 1

Invoke-Expression "$(thefuck --alias)"

if (-not $PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}
foreach ($Kvp in ([ordered]@{
    'Get-ChildItem:Force' = $true
}).GetEnumerator())
{
    $Global:PSDefaultParameterValues[$Kvp.Key] = $Kvp.Value
}
