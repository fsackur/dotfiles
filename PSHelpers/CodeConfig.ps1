function Read-CodeConfig
{
    param
    (
        [ValidateSet(
            "settings.json",
            "keybindings.json"
        )]
        [string]$Config = "settings.json",

        [switch]$Insiders
    )

    Import-Module Newtonsoft.Json -ErrorAction Stop

    $FolderName = if ($Insiders) {"Code - Insiders"} else {"Code"}
    $ConfigPath = Resolve-Path "~\AppData\Roaming\$FolderName\User\settings.json"


    # $ConfigPath = 'C:\dev\dotfiles\Code - Insiders\settings.json'

    $Start = $Previous = $Current = $null

    try
    {
        $ConfigLines = '', (gc $ConfigPath) | % {$_}
        $Stream = [System.IO.FileStream]::new($ConfigPath, "Open")
        $Reader = [IO.StreamReader]::new($Stream)
        $jtr=[Newtonsoft.Json.JsonTextReader]::new($Reader)
        $NestLevel = 0
        $Start = 1
        $Prop = $null
        $Output = [Collections.ArrayList]::new()

        while ($jtr.Read()) {
            $Current = $jtr | select *
            $TokenType = $Current.TokenType

            # Write-Host $TokenType, $NestLevel -ForegroundColor Green
            if
            (
                (
                    $NestLevel -eq 1 -and
                    $TokenType -in ('Comment', 'PropertyName') -and $Previous.TokenType -ne 'Comment' #-and
                    # $Previous.LineNumber -ne $Current.LineNumber
                ) -or
                (
                    $NestLevel -eq 1 -and
                    $TokenType -match '^End'
                )
            )
            {
                if ($Prop)
                {
                    # $Start, $Previous, $Current | ft TokenType, Line* | Out-String | write-host -ForegroundColor Green
                    $ChunkLines = $ConfigLines[$Start.LineNumber..($Previous.LineNumber)]
                    $ChunkLines[-1] = $ChunkLines[-1] -replace ('(?<=^' + ('.' * $Previous.LinePosition) + ').*')
                    $ChunkLines[0] = $ChunkLines[0] -replace ('^' + ('.' * $Start.LinePosition) + '\s*,\s*')

                    [void]$Output.Add(
                        [pscustomobject]@{
                            Name = $Prop
                            Text = ($ChunkLines -join [Environment]::NewLine).TrimEnd()
                        }
                    )
                }

                $Start = $Current | select *
                $BeforeStart = $Previous
                if ($Previous.LineNumber -eq $Start.LineNumber) {$Start.LinePosition = $Previous.LinePosition} else {$Start.LinePosition = 0}
            }
            $Previous = $Current

            if ($TokenType -match '^Start') {$NestLevel++} elseif ($TokenType -match '^End') {$NestLevel--}
            if ($NestLevel -eq 1 -and $TokenType -eq 'PropertyName') {$Prop = $Current.Value}
        }
    }
    finally
    {
        $Stream.Dispose()
        $Output | sort Name
    }

}
Read-CodeConfig | select -exp text
