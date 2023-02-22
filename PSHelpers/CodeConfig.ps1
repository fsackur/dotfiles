function Get-CodeSettingsPath
{
    param
    (
        [Parameter(Position = 0)]
        [ValidateSet(
            "settings.json",
            "keybindings.json"
        )]
        [string]$File = "settings.json",

        [switch]$Insiders
    )

    $FolderName = if ($Insiders) {"Code - Insiders"} else {"Code"}

    # TODO: xplat
    (Resolve-Path "~\AppData\Roaming\$FolderName\User\$File").Path
}


function Import-CodeSettings
{
    param
    (
        [ValidateSet(
            "settings.json",
            "keybindings.json"
        )]
        [string]$File = "settings.json",

        [switch]$Insiders
    )

    Import-Module Newtonsoft.Json -ErrorAction Stop


    $ConfigPath = Get-CodeSettingsPath @PSBoundParameters



    try
    {
        $ConfigLines = '', (gc $ConfigPath) | % {$_}    # Make 1-based array
        $Stream      = [System.IO.FileStream]::new($ConfigPath, "Open")
        $FileReader  = [IO.StreamReader]::new($Stream)
        $JsonReader  = [Newtonsoft.Json.JsonTextReader]::new($FileReader)

        #region First pass
        $Depth  = 0
        $Tokens = [Collections.ArrayList]::new()

        while ($JsonReader.Read())
        {
            $Current = $JsonReader | select *

            $Token = [pscustomobject]@{
                Type  = $Current.TokenType
                Depth = $Depth
                Name  = $Current.Value
                StartLine = [int]$Previous.LineNumber
                StartCol = [int]$Previous.LinePosition
                EndLine = [int]$Current.LineNumber
                EndCol = [int]$Current.LinePosition
            }
            [void]$Tokens.Add($Token)

            if ($Current.TokenType -match '^Start')
            {
                $Depth++
            }
            elseif ($Current.TokenType -match '^End')
            {
                $Depth--
            }

            $Previous = $Current
        }
        #endregion First pass
    }
    finally
    {
        $Stream.Dispose()
    }


    #region Second pass
    $Chunk          = [Collections.ArrayList]::new()
    $TopLevelTokens = [Collections.ArrayList]::new()
    $Start = $End = $Previous = $Current = $AttachedComment = $null
    foreach ($Token in $Tokens)
    {
        if ($Token.Depth -eq 1)
        {
            if (
                $Previous.Depth -ne 1 -or
                (
                    $Token.Type -eq "PropertyName" -or
                    ($Token.Type -eq "Comment" -and $Previous.Type -ne "Comment")
                )
            )
            {
                $Start = $Chunk[0]
                $End   = $Chunk[-1]
                $Chunk.Clear()

                $Lines     = $ConfigLines[($Start.StartLine)..($End.EndLine)]
                $Lines[-1] = $Lines[-1].SubString(0, $End.EndCol)
                $Lines[0]  = $Lines[0].SubString($Start.StartCol)


                # If the previous token was a comment - and we haven't already identified it as a
                # commented-out setting - then we assume it belongs to the current token.
                $Text = if ($AttachedComment)
                {
                    ($AttachedComment.Text, $Lines | % {$_}) -join [Environment]::NewLine
                }
                else
                {
                    $Lines -join [Environment]::NewLine
                }
                $Text = $Text -replace '^,?(\s*\r?\n)?'

                $TopLevelToken = [pscustomobject]@{
                    Type  = $Start.Type
                    Depth = $Start.Depth
                    Name  = $Start.Name
                    Text  = $Text
                }


                if ($TopLevelToken.Type -ne "Comment")
                {
                    $AttachedComment = $null
                    [void]$TopLevelTokens.Add($TopLevelToken)
                }
                else
                {
                    # When two commented-out settings are adjacent , we want to split them.
                    # Uncomment; try parsing; if it doesn't parse, treat it as a comment.
                    # This won't handle a valid commented-out setting adjacent to a text comment.
                    $Uncommented = $TopLevelToken.Text -replace '(?<=(^|\n)\s+)//' -replace '^', '{' -replace '$', '}'
                    try
                    {
                        $CommentLines = $TopLevelToken.Text -split '\r?\n'
                        $StartLine    = 0
                        foreach ($JToken in [Newtonsoft.Json.Linq.JToken]::Parse($Uncommented))
                        {
                            # PS does not handle IDynamicMetaObject well
                            $JToken             = $JToken | select *

                            $TopLevelToken      = $TopLevelToken | select *     # clone
                            $TopLevelToken.Type = "CommentedPropertyName"
                            $TopLevelToken.Name = $JToken.Path -replace "^(\['|\{)" -replace "(\}|'\])$"
                            $TopLevelToken.Text = $CommentLines[$StartLine..($JToken.LineNumber - 1)] -join [Environment]::NewLine

                            [void]$TopLevelTokens.Add($TopLevelToken)

                            $StartLine = $JToken.LineNumber
                        }
                    }
                    catch
                    {
                        # It's not a commented-out setting
                        $AttachedComment = $TopLevelToken
                    }
                }
            }
        }
        [void]$Chunk.Add($Token)
        $Previous = $Token
    }
    #region Second pass

    $Output = [ordered]@{}
    $TopLevelTokens | select -Skip 1 | group Name | sort Name | %{$Output.Add($_.Name, $_.Group.Text)}
    $Output
}



function Save-CodeSettings
{
    param
    (
        [ValidateSet(
            "settings.json",
            "keybindings.json"
        )]
        [string]$File = "settings.json",

        [switch]$Insiders,

        [string]$OutPath = (Split-Path $PSScriptRoot),

        [switch]$Split
    )


    [void]$PSBoundParameters.Remove('Split')
    [void]$PSBoundParameters.Remove('OutPath')
    $RealPath = Get-CodeSettingsPath @PSBoundParameters
    $Settings = Import-CodeSettings @PSBoundParameters

    $Join      = ",$([Environment]::NewLine)"
    $JoinBlock = ",$([Environment]::NewLine * 3)"

    $Blocks = $Settings.GetEnumerator() |
        group {$_.Key -replace '\..*'} |
        select (
            @{Name = 'Name'; Expression = {$_.Name -replace '$', '.json'}},
            @{Name = 'Text'; Expression = {$_.Group.Value -join $Join}}
        )

    if (-not $Split)
    {
        $Blocks = [pscustomobject]@{
            Name = $File
            Text = $Blocks.Text -join $JoinBlock
        }
    }


    $ChildPath = $RealPath -replace ('.*(?=' + $(if ($Insiders) {"Code - Insiders"} else {"Code"}) + ')')
    $OutPath   = $OutPath | Join-Path -ChildPath $ChildPath
    $OutPath   = if ($Split)
    {
        $OutPath -replace '\.json$'
    }
    else
    {
        $OutPath | Split-Path
    }

    if (-not (Test-Path $OutPath -PathType Container))
    {
        New-Item $OutPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    foreach ($Block in $Blocks)
    {
        $FilePath = Join-Path $OutPath ($Block.Name -replace '\[|\]')
        # Remove-Item $FilePath
        "{", $Block.Text, "}" | Out-File $FilePath -Encoding utf8 -Force
    }
}
