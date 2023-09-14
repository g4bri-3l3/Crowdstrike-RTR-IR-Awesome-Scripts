###############################################################################################################
###############################################################################################################
#### Script to wipe existing BitLocker key and create a new one, show it and finally ask for the password. ####
###############################################################################################################
###############################################################################################################

# Check if BitLocker is running
$bitlockerStatus = Get-BitLockerVolume -MountPoint "C:" | Select-Object -ExpandProperty VolumeStatus

if ($bitlockerStatus -eq "FullyEncrypted" -or $bitlockerStatus -eq "EncryptionInProgress") {
# BitLocker is running, so perform the actions
# Phase 1
# Wipe existing BitLocker protections
manage-bde -protectors -delete C:

# Phase 2
# Create new, randomly generated recovery password
manage-bde -protectors -add C: -RecoveryPassword

# Verify new recovery password will be required on next reboot
manage-bde -protectors -enable C:

# Display the BitLocker recovery key
$recoveryKey = manage-bde -protectors -get C: | Where-Object { $_ -like '*Recovery Password*' }
Write-Host "BitLocker Recovery Key: $recoveryKey"


# Phase 3
# Force the user to be prompted for new recovery password
manage-bde -forcerecovery C:

Write-Host "Done!!! Restarting system..."
# Reboot system to trigger recovery prompt
Restart-Computer -Force


} else {
    # If Bitlocker is not running or is in an incompatible state, display an error
    Write-Host "BitLocker is not running or in an incompatible state."
 }
