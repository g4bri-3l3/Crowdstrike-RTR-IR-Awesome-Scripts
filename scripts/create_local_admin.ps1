###############################################################################################################
###############################################################################################################
#### A simple script to create a local admin user. Replace the password ASAP!!! ###############################
###############################################################################################################
###############################################################################################################

param (
    [Parameter(Mandatory=$true, HelpMessage="Enter the username")]
    [string]$Username,

    # SecureString instead of plain string: a plaintext -Password on the
    # command line ends up verbatim in this process's command line, which is
    # captured by Win32_Process-based tooling (including this repo's own
    # ir_log_collector.ps1) and by RTR/Falcon audit logs. If omitted, a random
    # 20-character password is generated instead.
    [Parameter(Mandatory=$false, HelpMessage="SecureString password. If omitted, a random password is generated.")]
    [System.Security.SecureString]$Password,

    [Parameter(Mandatory=$true, HelpMessage="Enter the full name")]
    [string]$FullName,

    [Parameter(Mandatory=$true, HelpMessage="Enter the user description")]
    [string]$Description
)

if (-not $Password) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*_-+='
    $generatedPlaintext = -join ($chars.ToCharArray() | Get-Random -Count 20)
    $Password = ConvertTo-SecureString -String $generatedPlaintext -AsPlainText -Force
    Write-Warning "No -Password supplied - generated one. Record it now, it will not be shown again: $generatedPlaintext"
}

# Creating the user
try {
    New-LocalUser -Name $Username -Password $Password -FullName $FullName -Description $Description -ErrorAction Stop
    Add-LocalGroupMember -Group Administrators -Member $Username -ErrorAction Stop
    Write-Host "Local admin '$Username' created successfully. Replace/rotate this password ASAP."
}
catch {
    Write-Warning "Failed to create local admin '$Username': $($_.Exception.Message)"
}
