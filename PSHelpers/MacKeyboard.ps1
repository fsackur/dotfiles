function Get-KarabinerConfigPath
{
    "~/.config/karabiner/karabiner.json" | Resolve-Path | Select-Object -ExpandProperty Path
}

function Get-KarabinerCommand
{
    Get-Command '/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli'
}

function Invoke-Karabiner
{
    param
    (
        [ValidateSet(
            'select-profile',
            'show-current-profile-name',
            'list-profile-names',
            'set-variables',
            'copy-current-profile-to-system-default-profile',
            'remove-system-default-profile',
            'lint-complex-modifications',
            'version',
            'version-number',
            'help'
        )]
        [string]$Command,

        [Parameter(ValueFromRemainingArguments)]
        $ArgumentList
    )

    & (Get-KarabinerCommand) "--$Command" $ArgumentList
}

function Switch-KarabinerProfile
{
    [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidAssignmentToAutomaticVariable', '')]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({
            $Current = Invoke-Karabiner show-current-profile-name
            $All = Invoke-Karabiner list-profile-names
            $Names = (@($All) -ne $Current), $Current | Write-Output
            $Names -replace '.*\s.*', "'`$0'"
        })]
        $Profile
    )

    Invoke-Karabiner select-profile $Profile
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
    [CmdletBinding(DefaultParameterSetName = 'Current')]
    param
    (
        [Parameter(ParameterSetName = 'ByName', Mandatory, Position = 0)]
        [ArgumentCompleter({(Invoke-Karabiner list-profile-names) -replace '.*\s.*', "'`$0'"})]
        [SupportsWildcards()]
        $Name,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All
    )

    if ($PSCmdlet.ParameterSetName -eq 'Current')
    {
        $Name = Invoke-Karabiner show-current-profile-name
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'All')
    {
        $Name = '*'
    }

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
        [object]$Profile
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
        [Parameter(Position = 0)]
        [ArgumentCompleter({(Invoke-Karabiner list-profile-names) -replace '.*\s.*', "'`$0'"})]
        $Profile,

        [Parameter(Position = 1)]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $fakeBoundParameters.Remove($parameterName)
            $Rules = Get-KarabinerRule @fakeBoundParameters
            $Completions = (@($Rules.description) -ilike "$wordToComplete*"), (@($Rules.description) -ilike "*?$wordToComplete*") | Write-Output
            $Completions -replace '.*\s.*', "'`$0'"
        })]
        [SupportsWildcards()]
        $Description = '*'
    )

    $ProfileParams = if ($Profile) {@{Name = $Profile}} else {@{}}
    $_Profile = Get-KarabinerProfile @ProfileParams
    $Rules = $_Profile.complex_modifications.rules | Where-Object Description -like $Description
    $Rules | ForEach-Object {$_.PSTypeNames.Insert(0, 'KarabinerRule')}
    $Rules
}

function Set-KarabinerRule
{
    [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidAssignmentToAutomaticVariable', '')]
    param
    (
        [ArgumentCompleter({(Invoke-Karabiner list-profile-names) -replace '.*\s.*', "'`$0'"})]
        $Profile,

        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        $Rule
    )

    begin
    {
        $ProfileParams = if ($Profile) {@{Name = $Profile}} else {@{}}
        $_Profile = Get-KarabinerProfile @ProfileParams
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
