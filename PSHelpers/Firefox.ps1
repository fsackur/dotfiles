function Get-FirefoxProfilePath
{
    $FirefoxProfileRoot = "~/.mozilla/firefox" | Resolve-Path -ErrorAction Stop
    $Profiles = (Get-Content -Raw (Join-Path $FirefoxProfileRoot profiles.ini)) -split '(?<=^|\n)(?=\[\w+\])' | ForEach-Object Trim
    $_Profile = @($Profiles) -match '(?<=^|\n)Name=default-release' | Select-Object -First 1
    $ProfilePath = $_Profile -split '\n' -match '^Path=' -replace '^Path=' | Select-Object -First 1
    Join-Path $FirefoxProfileRoot $ProfilePath
}

function Get-FirefoxExtension
{
    param
    (
        [Parameter()]
        [SupportsWildcards()]
        [string]$Name = "*"
    )

    Get-FirefoxProfilePath -ErrorAction Stop | Push-Location -ErrorAction Stop

    try
    {
        $AddOns = gc ./addons.json |
            ConvertFrom-Json |
            % addons |
            ? {$_.name -like $Name -or $_.id -like $Name} |
            ForEach-Object {$_.PSTypeNames.Insert(0, "FirefoxAddOn"); $_}

        $ExtensionsById = gc ./extensions.json |
            ConvertFrom-Json |
            % addons |
            ForEach-Object {$_.PSTypeNames.Insert(0, "FirefoxExtension"); $_} |
            Group-Object id -AsHashTable

        $UuidsById = (gc ./prefs.js) -match '^user_pref\("extensions.webextensions.uuids"' -replace '^\S+,\s*"' -replace '"\);$' -replace '\\"', '"' |
            ConvertFrom-Json -AsHashtable

        $AddOns | ForEach-Object {
            $Id = $_.id
            [o]@{
                PSTypeName = "FirefoxExtensionInfo"
                Name = $_.name
                Id = $Id
                AddOn = $_
                Extension = $ExtensionsById[$Id]
                Uuid = $UuidsById[$id]
            }
        }
        # $ExtensionRoot = Join-Path (Get-FirefoxProfilePath) extensions
        # $XpiFiles = Get-ChildItem $ExtensionRoot -Filter *.xpi
        # $XpiFiles = $XpiFiles | Where-Object {$_.Name -like $Name -or $_.Name.StartsWith("{")}
        # $XpiFiles |
        #     ForEach-Object {unzip -p $_ manifest.json | ConvertFrom-Json}
        #     # Where-Object {$_.Name -like $Name}
    }
    finally
    {
        Pop-Location
    }
}
