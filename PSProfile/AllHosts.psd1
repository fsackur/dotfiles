@{
    CommandAliases     = @{}
    Vault              = @{}
    # LastSave           = $null
    # LastRefresh        = $null
    PathAliases        = @{}
    SymbolicLinks      = @{}
    ScriptPaths        = @(
        'C:\dev\dotfiles\PSProfile\Console.ps1',
        'C:\dev\dotfiles\Helpers\git_helpers.ps1',
        'C:\dev\dotfiles\Helpers\pipe_operators.ps1'
    )
    ModulesToImport    = @()
    Variables          = @{}
    Prompts            = @{}
    Plugins            = @()
    GitPathMap         = @{}
    Settings           = @{
        PSReadline            = @{
            KeyHandlers = @{

            }
            Options     = @{
                PredictionSource    = "History"
                MaximumHistoryCount = 16384
            }
        }
        # ConfigurationPath     = $null
        DefaultPrompt         = ''
        PSVersionStringLength = 3
        FontType              = 'Default'
        PromptCharacters      = @{
            AWS     = @{
                NerdFonts = ''
                Default   = 'AWS: '
                PowerLine = ''
            }
            GitRepo = @{
                NerdFonts = ''
                Default   = '@'
                PowerLine = ''
            }
        }
    }
    ProjectPaths       = @()
    # ConfigurationPaths = @()
    # PluginPaths        = $null
    PSBuildPathMap     = @{}
    RefreshFrequency   = '01:00:00'
    InitScripts        = @{}
    ModulesToInstall   = @(
        'Microsoft.PowerShell.SecretManagement',
        'Microsoft.PowerShell.SecretStore',
        'SecretManagement.BitWarden',
        'PSProfile',
        'oh-my-posh'
    )
}
