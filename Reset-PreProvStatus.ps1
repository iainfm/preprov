# Script to reset the pre-provisioning status so that it can be retried
# Iain McLaren (iain.mclaren@dvsa.gov.uk)
# 20 September 2022
# Version 0.2

Write-Output "`nDeleting registry values"

('DevicePreparationCategory.Status', 'DeviceSetupCategory.Status') | Where-Object { Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotSettings -name $_ -ErrorAction Ignore }

Write-Output "`nStarting Aik certificate enrollment task"

Get-ScheduledTask -taskname AikCertEnrollTask | Start-ScheduledTask

Write-Output "`nFinished. Check the output above and hit that retry button.`n"