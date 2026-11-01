#requires -Modules HomeAssistantX

$script:PSDefaultParameterValues['Connect-HomeAssistant:Uri'] = "https://gerty.dvlp.casa"
$script:PSDefaultParameterValues['Connect-HomeAssistant:AccessToken'] = {gc ~/.homeassistant}
$script:PSDefaultParameterValues['*-HomeAssistant*:Connection'] = {if ($null -eq $script:Gerty) {$script:Gerty = Connect-HomeAssistant}; $script:Gerty}

#region aliases
Set-Alias Connect-HA Connect-HomeAssistant
Set-Alias Disconnect-HA Disconnect-HomeAssistant
Set-Alias Export-HACameraSnapshot Export-HomeAssistantCameraSnapshot
Set-Alias Export-HADiagnostic Export-HomeAssistantDiagnostic
Set-Alias Find-HA Find-HomeAssistant
Set-Alias Get-HAAction Get-HomeAssistantAction
Set-Alias Get-HAApp Get-HomeAssistantApp
Set-Alias Get-HAArea Get-HomeAssistantArea
Set-Alias Get-HAAutomation Get-HomeAssistantAutomation
Set-Alias Get-HABackup Get-HomeAssistantBackup
Set-Alias Get-HACalendar Get-HomeAssistantCalendar
Set-Alias Get-HACalendarEvent Get-HomeAssistantCalendarEvent
Set-Alias Get-HACamera Get-HomeAssistantCamera
Set-Alias Get-HACategory Get-HomeAssistantCategory
Set-Alias Get-HAConnection Get-HomeAssistantConnection
Set-Alias Get-HADashboard Get-HomeAssistantDashboard
Set-Alias Get-HADevice Get-HomeAssistantDevice
Set-Alias Get-HAEnergy Get-HomeAssistantEnergy
Set-Alias Get-HAEntity Get-HomeAssistantEntity
Set-Alias Get-HAFloor Get-HomeAssistantFloor
Set-Alias Get-HAHistory Get-HomeAssistantHistory
Set-Alias Get-HAInfo Get-HomeAssistantInfo
Set-Alias Get-HAIntegration Get-HomeAssistantIntegration
Set-Alias Get-HAIssue Get-HomeAssistantIssue
Set-Alias Get-HAJob Get-HomeAssistantJob
Set-Alias Get-HALabel Get-HomeAssistantLabel
Set-Alias Get-HALog Get-HomeAssistantLog
Set-Alias Get-HALogbook Get-HomeAssistantLogbook
Set-Alias Get-HAMedia Get-HomeAssistantMedia
Set-Alias Get-HANotification Get-HomeAssistantNotification
Set-Alias Get-HAStatistic Get-HomeAssistantStatistic
Set-Alias Get-HATrace Get-HomeAssistantTrace
Set-Alias Get-HAUpdate Get-HomeAssistantUpdate
Set-Alias Get-HAWeather Get-HomeAssistantWeather
Set-Alias Install-HAUpdate Install-HomeAssistantUpdate
Set-Alias Invoke-HAAction Invoke-HomeAssistantAction
Set-Alias Invoke-HAApp Invoke-HomeAssistantApp
Set-Alias Invoke-HAAutomation Invoke-HomeAssistantAutomation
Set-Alias Invoke-HARecorderMaintenance Invoke-HomeAssistantRecorderMaintenance
Set-Alias Invoke-HARemote Invoke-HomeAssistantRemote
Set-Alias Invoke-HARoutine Invoke-HomeAssistantRoutine
Set-Alias New-HABackup New-HomeAssistantBackup
Set-Alias Receive-HACalendarEvent Receive-HomeAssistantCalendarEvent
Set-Alias Receive-HAEvent Receive-HomeAssistantEvent
Set-Alias Receive-HANotification Receive-HomeAssistantNotification
Set-Alias Receive-HAWeatherForecast Receive-HomeAssistantWeatherForecast
Set-Alias Remove-HAAutomation Remove-HomeAssistantAutomation
Set-Alias Remove-HACalendarEvent Remove-HomeAssistantCalendarEvent
Set-Alias Remove-HACategory Remove-HomeAssistantCategory
Set-Alias Remove-HADashboard Remove-HomeAssistantDashboard
Set-Alias Remove-HALabel Remove-HomeAssistantLabel
Set-Alias Remove-HANotification Remove-HomeAssistantNotification
Set-Alias Remove-HAStatistic Remove-HomeAssistantStatistic
Set-Alias Restart-HA Restart-HomeAssistant
Set-Alias Send-HANotification Send-HomeAssistantNotification
Set-Alias Set-HAAlarm Set-HomeAssistantAlarm
Set-Alias Set-HAAutomation Set-HomeAssistantAutomation
Set-Alias Set-HACalendarEvent Set-HomeAssistantCalendarEvent
Set-Alias Set-HACamera Set-HomeAssistantCamera
Set-Alias Set-HACategory Set-HomeAssistantCategory
Set-Alias Set-HAClimate Set-HomeAssistantClimate
Set-Alias Set-HACover Set-HomeAssistantCover
Set-Alias Set-HADashboard Set-HomeAssistantDashboard
Set-Alias Set-HAEnergy Set-HomeAssistantEnergy
Set-Alias Set-HAFan Set-HomeAssistantFan
Set-Alias Set-HAHelper Set-HomeAssistantHelper
Set-Alias Set-HAHumidifier Set-HomeAssistantHumidifier
Set-Alias Set-HALabel Set-HomeAssistantLabel
Set-Alias Set-HALawnMower Set-HomeAssistantLawnMower
Set-Alias Set-HALight Set-HomeAssistantLight
Set-Alias Set-HALock Set-HomeAssistantLock
Set-Alias Set-HAMediaPlayer Set-HomeAssistantMediaPlayer
Set-Alias Set-HASiren Set-HomeAssistantSiren
Set-Alias Set-HAStatistic Set-HomeAssistantStatistic
Set-Alias Set-HASwitch Set-HomeAssistantSwitch
Set-Alias Set-HAVacuum Set-HomeAssistantVacuum
Set-Alias Set-HAValve Set-HomeAssistantValve
Set-Alias Set-HAWaterHeater Set-HomeAssistantWaterHeater
Set-Alias Test-HAAutomationDraft Test-HomeAssistantAutomationDraft
Set-Alias Test-HAConfiguration Test-HomeAssistantConfiguration
Set-Alias Test-HAStatistic Test-HomeAssistantStatistic
#endregion aliases

function Find-HASpellingError {
    [CmdletBinding()]
    param ()

    $Entities = Get-HAEntity

    $Entities |
        ? {
            ($_.EntityId -replace ".*\." -replace "_", " ") -ine
            ($_.Name -replace "'" -replace " - ", " " -replace "-", " " -replace "Duration", "action duration" -replace "\.", " ")
        } |
        Select-Object EntityId, Name, DeviceName
}
