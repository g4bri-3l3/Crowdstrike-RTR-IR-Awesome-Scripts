###############################################################################################################
###############################################################################################################
#### Script to remove (or disable) a local admin created with create_local_admin.ps1. #########################
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Removes or disables a local user, typically the emergency admin from create_local_admin.ps1.
.DESCRIPTION
    The account is removed (or disabled with -Disable); active sessions are not logged off.
    Every action is appended to a log file with a timestamp, so there is a trace of when the
    account was removed. The built-in Administrator (RID 500) is never touched.
.PARAMETER Username
    Local account to remove.
.PARAMETER Disable
    Disable the account instead of deleting it (keeps the profile/SID for investigation).
.PARAMETER LogPath
    Where to append the action log (default C:\Windows\Temp\local_admin_changes.log).
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [switch]$Disable,

    [string]$LogPath = "C:\Windows\Temp\local_admin_changes.log"
)

function Write-Log {
    param([string]$Message)
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $env:COMPUTERNAME, $Message
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue
}

try {
    $user = Get-LocalUser -Name $Username -ErrorAction Stop
}
catch {
    Write-Log "User '$Username' not found - nothing to do."
    return
}

if ($user.SID.Value -match '-500$') {
    Write-Log "Refusing to modify '$Username': it is the built-in Administrator account."
    return
}

try {
    if ($Disable) {
        Disable-LocalUser -Name $Username -ErrorAction Stop
        Write-Log "Disabled local user '$Username'."
    }
    else {
        Remove-LocalUser -Name $Username -ErrorAction Stop
        Write-Log "Removed local user '$Username'."
    }
}
catch {
    Write-Log "FAILED to $(if ($Disable) { 'disable' } else { 'remove' }) '$Username': $($_.Exception.Message)"
}
