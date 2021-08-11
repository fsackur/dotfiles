
if (-not $PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}
foreach ($Kvp in ([ordered]@{
    'Out-Default:OutVariable' = '+LastOutput'
    'Get-ChildItem:Force'     = $true
}).GetEnumerator())
{
    $Global:PSDefaultParameterValues[$Kvp.Key] = $Kvp.Value
}
