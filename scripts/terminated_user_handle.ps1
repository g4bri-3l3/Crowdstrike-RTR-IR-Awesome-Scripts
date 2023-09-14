###############################################################################################################
###############################################################################################################
#### Script to handle a terminated user. Immediately remediate the endpoint. ##################################
###############################################################################################################
###############################################################################################################


<#
.SYNOPSIS
    Protects a Windows computer endpoint upon user termination from the terminated user.
.DESCRIPTION
    This script takes the following actions:
    - Log off all users
    - Disables cached credentials
    - Changes local account passwords
    - Clears Kerberos tickets
    - Shuts down the computer
	
	
#Credits to finackninja https://github.com/finackninja/CSFRTR for the base script
#>

[CmdletBinding()]
Param ()

# Define excluded local accounts
$ExcludedLocalAccounts = @(
    'DefaultAccount',
    'WDAGUtilityAccount'
)

# Log off all current user sessions
Invoke-CimMethod -ClassName Win32_Operatingsystem -ComputerName . -MethodName Win32Shutdown -Arguments @{ Flags = 4 }

# Disable cached credentials (requires a reboot)
try {
    $logonSettingsPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    if ((Get-ItemProperty -Path $logonSettingsPath -Name CachedLogonsCount).CachedLogonsCount -ne 0) {
        Set-ItemProperty -Path $logonSettingsPath -Name CachedLogonsCount -Value 0
        Write-Warning 'This change requires a reboot to take effect. Please reboot the computer when appropriate.'
    }
}
catch {
    Write-Warning 'Unable to disable cached credentials.'
}

# Function to generate a random password
function Generate-RandomPassword {
    $characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890~!@#$%^&*_-+=`|\(){}[]:;`"<>,.?/'
    $passwordLength = 20
    $password = ""
    
    for ($i = 0; $i -lt $passwordLength; $i++) {
        $password += $characters | Get-Random
    }

    return $password
}

# Change passwords for local user accounts
Get-LocalUser | Where-Object { $ExcludedLocalAccounts -notcontains $_.Name } | ForEach-Object {
    try {
        $Password = Generate-RandomPassword
        $_ | Set-LocalUser -Password (ConvertTo-SecureString -String $Password -AsPlainText -Force) -ErrorAction Stop
        Write-Host "Password for $($_.Name) changed successfully."
    }
    catch {
        Write-Warning "Unable to change the password for $($_.Name)."
    }
}

# Clear all Kerberos tickets (run as a separate job)
Start-Job -ScriptBlock {
    Get-CimInstance -ClassName 'Win32_LogonSession' -ErrorAction Stop | Where-Object { $_.AuthenticationPackage -ne 'NTLM' } | ForEach-Object {
        klist.exe purge -li ([Convert]::ToString($_.LogonId, 16)) 
    }
}

# Provide a cushion to allow the Kerberos ticket clear job an opportunity to complete
Start-Sleep -Seconds 5

# Shutdown the computer once completed
Stop-Computer -Force
