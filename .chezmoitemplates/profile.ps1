. "{{ .chezmoi.sourceDir }}/PSHelpers/Console.ps1"
. "{{ .chezmoi.sourceDir }}/PSHelpers/git_helpers.ps1"
. "{{ .chezmoi.sourceDir }}/PSHelpers/pipe_operators.ps1"
. "{{ .chezmoi.sourceDir }}/PSHelpers/ModuleLoad.ps1"

if (Test-Path "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1")
{
    . "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1"
}
