function Find-GithubCode
{
    <#
        Repository qualifier (e.g. repo:github/primer)
        Organization qualifier (e.g. org:github, or equivalently user:colinwm)
        Language qualifier (e.g. language:python)
        Path qualifier (e.g. path:README.md)
        Symbol qualifier (e.g. symbol:scanbytes)
        Content qualifier (e.g. content:querystats)
        Is qualifier (e.g. is:archived)

        .NOTES
        Sign up for code search access at https://cs.github.com/about
    #>

    [CmdletBinding(
        HelpUri = 'https://cs.github.com/about/syntax'
    )]
    param
    (
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$SearchTerm,

        [switch]$Regex,

        [string]$Repo,

        [Alias('Org')]
        [string]$User,

        [string]$Language,

        [string]$Path,

        [string]$Symbol,

        [string]$Content,

        [ValidateSet('archived')]
        [string[]]$Is,

        [uri]$Uri = 'https://github.com'
    )

    $Type = 'code'

    $Builder = [UriBuilder]::new($Uri.Scheme, $Uri.Host)
    $Builder.Path = 'search'

    if ($Regex -and $SearchTerm)
    {
        $SearchTerm = "/$SearchTerm/"
    }

    [void]$PSBoundParameters.Remove('SearchTerm')
    [void]$PSBoundParameters.Remove('Regex')
    [void]$PSBoundParameters.Remove('Uri')

    $Terms = $SearchTerm, (
        $PSBoundParameters.GetEnumerator() |
            ForEach-Object {
                $Keyword = $_.Key.ToLower()
                $_.Value | ForEach-Object {$Keyword, $_ -join ':'}
            }
    ) | ForEach-Object {[Web.HttpUtility]::UrlEncode($_)}

    $Builder.Query = "type=$Type&q=$($Terms -join '+')"

    Start-Process $Builder.ToString()
}

Register-ArgumentCompleter -CommandName Find-GithubCode -ParameterName Language -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    if (-not $Script:GithubSupportedLanguages)
    {
        $Yaml = Invoke-WebRequest https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml | Select-Object -ExpandProperty Content
        $Script:GithubSupportedLanguages = $Yaml -split '\n' -match '^\w' -replace ':$'
    }
    $Script:GithubSupportedLanguages -like "$wordToComplete*" -replace '(\S*)( .*)', '"$1$2"'
}

class UriTransformAttribute : Management.Automation.ArgumentTransformationAttribute
{
    [object] Transform([Management.Automation.EngineIntrinsics]$engineIntrinsics, [object]$inputData) {
        if ($inputData -is [uri]) {
            return $inputData
        }

        [uri]$Uri = $null
        if ([uri]::TryCreate($inputData, 1, [ref]$Uri)) {
            return $Uri
        }

        return ""  # won't bind to Uri
    }
}

function Get-GithubRelease
{
    [CmdletBinding(DefaultParameterSetName = 'Uri')]
    param
    (
        [Parameter(ParameterSetName = 'Uri', Mandatory, Position = 0)]
        [uri][UriTransformAttribute()]$Uri,

        [Parameter(ParameterSetName = 'OrgRepo', Mandatory, Position = 0)]
        [Alias('User')]
        [string]$Org,

        [Parameter(ParameterSetName = 'OrgRepo', Mandatory, Position = 1)]
        [string]$Repo
    )

    if ($PSCmdlet.ParameterSetName -eq "Uri") {
        $Org, $Repo = if ($Uri.DnsSafeHost -eq "github.com") {
            ($Uri.Segments -replace '/$')[1,2]
        } else {
            throw "Can't parse org and repo from uri: $Uri"
        }
    }

    Invoke-RestMethod "https://api.github.com/repos/$Org/$Repo/releases"
}

function Find-GithubAsset
{
    [OutputType([uri[]])]
    [CmdletBinding(DefaultParameterSetName = 'Uri', PositionalBinding = $false)]
    param
    (
        [Parameter(ParameterSetName = 'Uri', Mandatory, Position = 0)]
        [uri][UriTransformAttribute()]$Uri,

        [Parameter(ParameterSetName = 'OrgRepo', Mandatory, Position = 0)]
        [Alias('User')]
        [string]$Org,

        [Parameter(ParameterSetName = 'OrgRepo', Mandatory, Position = 1)]
        [string]$Repo,

        [SupportsWildcards()]
        [string]$Tag = '*',

        [Parameter(ValueFromPipeline)]
        [SupportsWildcards()]
        [string[]]$Filter,

        [switch]$Regex,

        [switch]$AllowPrerelease
    )

    begin
    {
        $Releases = if ($PSCmdlet.ParameterSetName -eq "Uri") {
            Get-GithubRelease $Uri
        } else {
            Get-GithubRelease $Org $Repo
        }

        $Latest = $Releases |
            Where-Object {$_.tag_name -like $Tag} |
            Where-Object {$AllowPrerelease -or -not $_.prerelease} |
            Select-Object -First 1
    }

    process
    {
        $Assets = if ($Regex)
        {
            $Pattern = $Filter -join '|'
            $Latest.assets | Where-Object {$_.name -match $Pattern}
        }
        elseif ($Filter)
        {
            foreach ($Filter in $Filter)
            {
                $Latest.assets | Where-Object {$_.name -like $Filter}
            }
        }
        else
        {
            $Latest.assets
        }

        $Assets.browser_download_url
    }
}
