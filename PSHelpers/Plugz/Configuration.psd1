@{
  PluginPath = @('C:/dev/dotfiles/Corp','C:/dev/dotfiles/PSHelpers')
  RunFirst = @('Console.ps1','Env.ps1','WaeEnv.ps1','PS_profile.ps1','git_helpers.ps1','pipe_operators.ps1','ModuleLoad.ps1','Wsl.ps1','WorkHelpers.ps1','AzureEnv.ps1')
  RunWhen = @(@{
    Condition = (ScriptBlock '$Global:IS_ISE')
    Script = 'ISE_profile.ps1'
  },@{
    Condition = (ScriptBlock '$Global:IS_VSCODE')
    Script = 'VSCode_profile.ps1'
  })
}
