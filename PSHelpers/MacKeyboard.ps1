function Get-KarabinerConfigPath
{
    "~/.config/karabiner/karabiner.json" | Resolve-Path | Select-Object -ExpandProperty Path
}

function Get-KarabinerConfig
{
    $Config = Get-KarabinerConfigPath | Resolve-Path | Get-Content | ConvertFrom-Json
    $Config.PSTypeNames.Insert(0, 'KarabinerConfig')
    $Config
}

function Set-KarabinerConfig
{
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        $Config
    )

    $ConfigPath = Get-KarabinerConfigPath
    $Config | ConvertTo-Json -Depth 20 | Set-Content $ConfigPath
}

function Get-KarabinerProfile
{
    param
    (
        [SupportsWildcards()]
        $Name = '*'
    )

    $Config = Get-KarabinerConfig
    $Profiles = $Config.profiles | Where-Object Name -like $Name
    $Profiles | ForEach-Object {$_.PSTypeNames.Insert(0, 'KarabinerProfile')}
    $Profiles
}

function Set-KarabinerProfile
{
    [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidAssignmentToAutomaticVariable', '')]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        $Profile
    )

    begin
    {
        $Config = Get-KarabinerConfig
    }

    process
    {
        $Names = @($Config.profiles.name)
        $Index = $Names.IndexOf($Profile.Name)
        if ($Index -eq -1)
        {
            $Config.profiles += $Profile
        }
        else
        {
            $Config.profiles[$Index] = $Profile
        }
    }

    end
    {
        $Config | Set-KarabinerConfig
    }
}

function Get-KarabinerRule
{
    [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidAssignmentToAutomaticVariable', '')]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        $Profile,

        [Parameter(Position = 1)]
        [SupportsWildcards()]
        $Description = '*'
    )

    $_Profile = Get-KarabinerProfile $Profile
    $Rules = $_Profile.complex_modifications.rules | Where-Object Description -like $Description
    $Rules | ForEach-Object {$_.PSTypeNames.Insert(0, 'KarabinerRule')}
    $Rules
}

function Set-KarabinerRule
{
    [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidAssignmentToAutomaticVariable', '')]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        $Profile,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
        $Rule
    )

    begin
    {
        $_Profile = Get-KarabinerProfile $Profile
        $Rules = $_Profile.complex_modifications.rules
    }

    process
    {
        $Descriptions = @($Rules.description)
        $Index = $Descriptions.IndexOf($Rule.description)
        if ($Index -eq -1)
        {
            $Rules += $Rule
            $Rules = $_Profile.complex_modifications.rules
        }
        else
        {
            $Rules[$Index] = $Rule
        }
    }

    end
    {
        $_Profile | Set-KarabinerProfile
    }
}

$KarabinerProfileCompleter = {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    if (-not $Script:KarabinerProfiles)
    {
        $Script:KarabinerProfiles = (Get-KarabinerConfig).profiles.Name
    }
    $Completions = (@($Script:KarabinerProfiles) -like "$wordToComplete*"), (@($Script:KarabinerProfiles) -like "*.$wordToComplete*") | Write-Output
    $Completions -replace '.*\s.*', "'`$0'"
}

Register-ArgumentCompleter -CommandName Get-KarabinerProfile, Set-KarabinerProfile -ParameterName Name -ScriptBlock $KarabinerProfileCompleter
Register-ArgumentCompleter -CommandName Get-KarabinerRule, Set-KarabinerRule -ParameterName Profile -ScriptBlock $KarabinerProfileCompleter
