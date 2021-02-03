
if (-not $PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}
foreach ($Kvp in ([ordered]@{
    'Out-Default:OutVariable' = '+LastOutput'
}).GetEnumerator())
{
    $Global:PSDefaultParameterValues[$Kvp.Key] = $Kvp.Value
}
