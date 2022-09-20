# Script to wait for Bitlocker encryption at pre-provisioning phase, kick stalled encryptions and check provider thing
# Iain McLaren (iain.mclaren@dvsa.gov.uk)
# 16 September 2022
# Version 1.0


# Wait for bitlocker encryption to complete and pause/resume it if it sticks.

Write-Host

Write-Host "Waiting for Bitlocker Encryption to complete..."

Write-Host

$last_percent = 0

$this_percent = (Get-BitLockerVolume -MountPoint C:).EncryptionPercentage

while ($this_percent -ne 100) {

    if ($this_percent -ne $last_percent) {

        Write-Output "Encryption percentage : $this_percent"

    }

    else {

        Write-Host -ForegroundColor Red "Encryption stalled - pausing Bitlocker..."

        manage-bde -pause C:

        Start-Sleep 5

        Write-Host -ForegroundColor Red "...and resuming."

        manage-bde -resume C:

    }

    Start-Sleep 60

    $last_percent = $this_percent

    $this_percent = (Get-BitLockerVolume -MountPoint C:).EncryptionPercentage

}

Write-Host

Write-Host -ForegroundColor Green "Encryption has completed."

Write-Host


# Check protection is on and attempt to enable it if not

Write-Host "Checking protection is enabled..."

Write-Host

$count = 0

while ((((manage-bde -status c:) -match "Protection On").Count -eq 0) -and $count -ne 10) {

    Write-Host -ForegroundColor Yellow "Protection is off. Enabling..."

    Enable-BitLocker -MountPoint C: -TpmProtector

    manage-bde -on C:

    $count = $count + 1

    Start-Sleep 10

}

Write-Host

if (((manage-bde -status c:) -match "Protection On").Count -eq 0) {

    Write-Host -ForegroundColor Red "Protection has failed. Please check and remedy before resealing this device."

}

else {

    Write-Host -ForegroundColor Green "Protection status is on. Device is ready to be resealed."

}