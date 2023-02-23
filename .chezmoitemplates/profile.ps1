. "{{ .chezmoi.sourceDir }}/PSHelpers/Console.ps1"
. "{{ .chezmoi.sourceDir }}/PSHelpers/git_helpers.ps1"
. "{{ .chezmoi.sourceDir }}/PSHelpers/pipe_operators.ps1"
. "{{ .chezmoi.sourceDir }}/PSHelpers/ModuleLoad.ps1"

if (Test-Path "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1")
{
    . "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1"
    {{ if hasSuffix "dev.wham.rackspace.net" (lower .chezmoi.fqdnHostname)}}. "{{ .chezmoi.sourceDir }}/Work/DevenvEnv.ps1"{{ end }}
}
