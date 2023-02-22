function New-ModuleRepo
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [Alias('ModuleName')]
        [string]$Name,

        [string]$Description,

        [string[]]$Tag,

        [string]$ProjectRootPath = $(
            # Allow user to override GIT_REPO_ROOT
            # The double-use of Resolve-Path fixes path case, which matters on *nix and also for Gitlens
            # Windows is happy to resolve /Githubdata to C:\Githubdata
            $GIT_REPO_ROOT, $env:GIT_REPO_ROOT, '/Githubdata', $XDG_CONFIG_HOME, $env:XDG_CONFIG_HOME |
                Resolve-Path -ErrorAction SilentlyContinue -Relative |
                Resolve-Path -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty Path
        )
    )

    $ModuleName  = $Name
    $Encoding    = 'utf8'

    $Manifest    = "$ModuleName.psd1"
    $RootModule  = "$ModuleName.psm1"
    $ProjectUri  = "https://github.com/fsackur/$ModuleName"
    $HelpInfoURI = "https://pages.github.com/fsackur/$ModuleName"
    $LicenseUri  = "https://raw.githubusercontent.com/fsackur/$ModuleName/main/LICENSE"
    $Year        = [datetime]::Today.Year
    $Guid        = (New-Guid).Guid
    $TagString   = if ($Tag) {"'$($Tag -join "', '")'"}

    function Replace-TemplateVariable
    {
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
            [string]$Template
        )

        begin
        {
            $Regex = [regex]'<%=\$(?<Name>\w+)%>'
            $MatchEvaluator = {
                param
                (
                    [Text.RegularExpressions.Match]$Match
                )
                $Name = $Match.Groups | Where-Object Name -eq 'Name' | Select-Object -ExpandProperty Value
                Get-Variable $Name -ValueOnly
            }
        }

        process
        {
            $Regex.Replace($Template, $MatchEvaluator)
        }
    }

    function ConvertTo-LF
    {
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
            [string]$InputObject
        )

        process
        {
            $_ -replace '\r'
        }
    }

    #region Templates
    $LicenseTemplate = @'
MIT License

Copyright (c) <%=$Year%> Freddie Sackur

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'@ -replace '\r'

    $VSCodeSettingsTemplate = @'
{
    "files.trimTrailingWhitespace": true,
    "editor.tabSize": 4,
    "editor.renderWhitespace": "none",
    "files.eol": "\n",
    "files.encoding": "utf8",
    "files.insertFinalNewline": true,
    "files.trimFinalNewlines": true
}
'@ -replace '\r'

    $Psd1Template = @'
@{
    Description          = '<%=$Description%>'
    ModuleVersion        = '0.0.1'
    HelpInfoURI          = '<%=$HelpInfoURI%>'
    GUID                 = '<%=$Guid%>'

    RequiredModules      = @()

    Author               = 'Freddie Sackur'
    CompanyName          = 'DustyFox'
    Copyright            = '(c) <%=$Year%> Freddie Sackur. All rights reserved.'

    RootModule           = '<%=$RootModule%>'

    FunctionsToExport    = @(
        '*'
    )

    PrivateData          = @{
        PSData = @{
            LicenseUri = '<%=$LicenseUri%>'
            ProjectUri = '<%=$ProjectUri%>'
            Tags       = @(<%=$TagString%>)
        }
    }
}
'@ -replace '\r'

    $Psm1Template = @'

Get-ChildItem $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue | ForEach-Object {. $_.FullName}
Get-ChildItem $PSScriptRoot\Public\*.ps1  -ErrorAction SilentlyContinue | ForEach-Object {. $_.FullName}
'@ -replace '\r'
    #endregion Templates

    $Path = Join-Path $ProjectRootPath $ModuleName
    try
    {
        $null = New-Item $Path -ItemType Directory -Force -ErrorAction Stop
    }
    catch
    {
        if ($_ -notmatch 'already exists') {throw}
    }
    Push-Location $Path -ErrorAction Stop

    try
    {
        $GitDir = git rev-parse --git-dir 2>&1
        if ($?) {throw "Git repository already initialised: $GitDir"}

        $ErrorActionPreference = 'Stop'

        $GitInit = git init --initial-branch=main 2>&1
        if (-not $?) {throw "Git init: $GitInit"}

        git remote add origin $ProjectUri
        # TODO: github API call
        # git fetch origin
        # git branch -u origin/main

        $LicenseTemplate | Replace-TemplateVariable | Out-File 'LICENSE' -Encoding $Encoding
        git add *
        git commit -m 'Initial commit'

        $null = New-Item .vscode -ItemType Directory
        $VSCodeSettingsTemplate | Replace-TemplateVariable | Out-File '.vscode/settings.json' -Encoding $Encoding
        git add *
        git commit -m 'Editor settings'

        $Psd1Template | Replace-TemplateVariable | Out-File "$ModuleName.psd1" -Encoding $Encoding
        $Psm1Template | Replace-TemplateVariable | Out-File "$ModuleName.psm1" -Encoding $Encoding
        git add *
        git commit -m 'Module initialisation'

        $null = New-Item Private -ItemType Directory
        $null = New-Item Public -ItemType Directory
    }
    finally
    {
        Pop-Location
    }
}
