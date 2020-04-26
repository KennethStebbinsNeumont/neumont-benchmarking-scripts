$WMIWin32_BIOS = Get-WmiObject -Class Win32_BIOS
$WMIWin32_ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem

$serial = $WMIWin32_BIOS.SerialNumber
$biosVersionName = $WMIWin32_BIOS.SMBIOSBIOSVersion -replace " \(.*\)", ""

$model_name = $WMIWin32_ComputerSystem.Model
$mfr_name = $WMIWin32_ComputerSystem.Manufacturer

Write-Host "Serial number: $serial"
Write-Host "Model: $model_name"
Write-Host "BIOS version name: $biosVersionName"
Write-Host "Manufacturer: $mfr_name"


########## Lenovo P1 gen 2 Output ###########
# Serial number: R90W6AP8
# Model: 20QUS0PW00
# BIOS version name: N2OET40W
# Manufacturer: LENOVO
#############################################