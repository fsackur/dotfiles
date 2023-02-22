function Build-Module
{
    [CmdletBinding()]
    param
    (
        [string]$Path = '.',

        [string]$OutPath = (Join-Path $Path Build),

        [string[]]$CodeFolders = ('Classes', 'Private', 'Public'),

        [string[]]$VerbatimFolders = ('Resource', 'Tests', 'Tools')
    )

    $Path = $Path | Resolve-Path

    $Module = Get-Module $Path -ListAvailable -ErrorAction Stop


    if ($OutPath.StartsWith('~'))
    {
        $OutPath = Join-Path ('~' | Resolve-Path) $OutPath.Substring(1)
    }
    if (-not [IO.Path]::IsPathRooted($OutPath))
    {
        $OutPath = Join-Path $Path $OutPath
    }

    $null = New-Item $OutPath -ItemType Directory -Force
    $OutPath |
        Get-ChildItem |
        Remove-Item -Recurse -Force


    $Psd1Path = Join-Path $OutPath (Split-Path $Module.Path -Leaf)
    $Psm1Path = Join-Path $OutPath $Module.RootModule

    $Psd1Content = Get-Content $Module.Path -Raw
    $Psd1 = Invoke-Expression "DATA {$Psd1Content}"
    $NestedModules = $Psd1.NestedModules -match "\b$($CodeFolders -join '|')\b"
    if ($NestedModules)
    {
        $Psd1Content = $Psd1Content -replace "\s+[`"']($($NestedModules -join '|'))[`"'],?\s*\r?\n?"
    }
    $Psd1Content |
    Add-Content $Psd1Path -Encoding utf8


    $CodeFolders = $CodeFolders |
        ForEach-Object {Join-Path $Path $_} |
        Resolve-Path -ErrorAction Ignore |
        Where-Object Path

    $CodeFolders |
        Get-ChildItem |
        Where-Object Extension -match '\.ps(m?)1' |
        ForEach-Object {
            Get-Content $_
            ""
        } |
        Out-String |
        Add-Content $Psm1Path -Encoding utf8


    $VerbatimFolders = $VerbatimFolders |
        ForEach-Object {Join-Path $Path $_} |
        Resolve-Path -ErrorAction Ignore |
        Where-Object Path

    $VerbatimFolders |
        Copy-Item -Destination $OutPath -Recurse


    Join-Path $Path $Module.RootModule |
        Resolve-Path |
        Get-Content |
        Select-String -NotMatch 'Diagnostics.CodeAnalysis|param|Get-ChildItem' |
        Add-Content $Psm1Path -Encoding utf8
}
