# Script to check whether pre-provisioning is likely to be successful
# Iain McLaren (iain.mclaren@dvsa.gov.uk)
# 16 September 2022
# Version 1.0

function Get-RegKeyValue {

    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]$Value
    )

try {

    Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null

    return $true

}

catch {

    return $false

}

}

function Test-Internet ($hostname='8.8.8.8',$port=53,$timeout=100) {

    $requestCallback = $state = $null

    $client = New-Object System.Net.Sockets.TcpClient

    $beginConnect = $client.BeginConnect($hostname,$port,$requestCallback,$state)

    Start-Sleep -milli $timeOut

    if ($client.Connected) { $open = $true } else { $open = $false }

    $client.Close()

    [pscustomobject]@{hostname=$hostname;port=$port;open=$open}

}

Write-Host

Write-Output "Testing network connectivity..."

if ((Test-Internet).Open -eq $True) {

    write-host -ForegroundColor Green "Success"

}

else {

    Write-Host -ForegroundColor Red "Failed to contact Google DNS. Please check network cabling etc and try again."

    exit

}

Write-Host

Write-Output "Checking EULA has been accepted..."

$rpath = 'hklm:\software\microsoft\windows\currentversion\setup\oobe'

$rvalue = 'SetupDisplayedEula'

if ((Get-RegKeyValue -Path $rpath -Value $rvalue) -eq $true) {

    write-host -ForegroundColor Green "EULA acceptance is present"

}

else {

    write-host -ForegroundColor Yellow "Creating EULA acceptance registry value..."

try {

    New-ItemProperty -Path $rpath -Name $rvalue -Value 1 -PropertyType 'DWord' | out-null

    write-host -ForegroundColor Green "EULA acceptance registry value created."

}

catch {

    write-host -ForegroundColor Red "Could not create EULA registry value. Please try manually."

}

}

Write-Host

Write-Output "Peforming TPM checks..."

if (((get-tpm).tpmready -eq $False) -or ((get-tpm).tpmpresent -eq $False) -or ((get-tpm).enabled -eq $False)) {

    write-host -ForegroundColor Red "TPM not available. Please check BIOS settings."

    exit

}

$count = 0

while (((get-tpm).TPMOwned -eq $False) -and ($count -ne 10)) {

    write-output "TPM is not owned. Attempting to initialise..."

    $count = $count + 1

    write-host -ForegroundColor Yellow "Attempt: $count"

    Initialize-TPM

    Start-Sleep 10

}

if ((get-tpm).TPMOwed -eq $False) {

    write-host -ForegroundColor Red "Failed to initialise TPM. Cannot continue."

    exit

}

$count = 0

write-host -ForegroundColor Green "TPM has been initialised."

Write-Host

write-output "Checking for TPM Maintenance task completion."

while ((((((tpmtool getdeviceinformation) -match "Maintenance") -match "True")).count -eq 0) -and ($count -ne 10)) {

    $count = $count + 1

    Write-Host -ForegroundColor Yellow "Attempt: $count"

    Get-ScheduledTask -TaskName "Tpm-Maintenance" | Start-ScheduledTask

    Start-Sleep 10

}

if ((((tpmtool getdeviceinformation) -match "Maintenance") -match "True").count -eq 0) {

    write-host -ForegroundColor Red "TPM Maintenance task is not completing. Try running the script again?"

    exit

}

write-host -ForegroundColor Green "Maintenance task has completed."

Write-Host

Write-Output "Checking EK Cert is installed."

if ((((tpmtool getdeviceinformation) -match "INFORMATION_EK_CERTIFICATE") -match "True").count -ne 0) {

    write-host -ForegroundColor Red "EK Cert is still missing. Try running the script again?"

    exit

}

write-host -ForegroundColor Green "EK Cert appears to be present."

Write-Host

write-output 'Checking for manufacturer certificates'

$count = 0

while ((((Get-TpmEndorsementKeyInfo).ManufacturerCertificates).Count -eq 0) -and ($count -ne 10)) {

    $count = $count + 1

    Write-Host -ForegroundColor Yellow "Attempt: $count"

    # Not much to do here apart from wait...

    Start-Sleep 10

}

if (((Get-TpmEndorsementKeyInfo).ManufacturerCertificates).Count -eq 0) {

    Write-Host -ForegroundColor Red "No manufacturer certificates are present. Continuing anyway."

}

else {

    Write-Host -ForegroundColor Green "Manufacturer certificate are present."

}

Write-Host -ForegroundColor Yellow "Informational: There are $(((Get-TpmEndorsementKeyInfo).ManufacturerCertificates).Count) additional certificates present."

Write-Host

Write-Output "Checking whether Microsoft's certificate servers are working..."

$count = 0

while (((cmd /c "certreq -q -enrollaik -config """).Contains('HTTP/1.1 200 OK') -eq $False) -and ($count -ne 10)) {

    Write-Host -ForegroundColor Yellow "Attempt: $count"

    Start-Sleep 10

}

if ((cmd /c "certreq -q -enrollaik -config """).Contains('HTTP/1.1 200 OK') -eq $True) {

    write-host -ForegroundColor Green "A certificate was received." 
    
    }
    
    else {
    
    write-host -ForegroundColor Red "No certificate was received. Check network connections or try again later."
    
}
    
Write-Host

Write-Host -ForegroundColor Blue "All possible fixes have been done. Try pre-provisioning the device."