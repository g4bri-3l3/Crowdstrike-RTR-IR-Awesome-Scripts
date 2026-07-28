###############################################################################################################
###############################################################################################################
#### Script to dump the network traffic on a host (file will go up to 1Gb). ###################################
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Captures network traffic on a host via netsh trace, with a size cap based on
    free disk space instead of a fixed value.
.DESCRIPTION
    Same underlying netsh trace approach as before, with one change: the max capture
    size is capped to 50% of free space on the destination drive (same safety limit
    used by https://github.com/C0ubv9/CS_PacketCap), so the capture can't fill the 
    disk on hosts with little free space.
.PARAMETER DesiredMaxSizeMB
    Preferred capture size cap in MB (default 1000). Actual cap is the lower of this
    value and 50% of free space on the destination drive.
#>

[CmdletBinding()]
Param (
    [int]$DesiredMaxSizeMB = 1000
)

# Check if the destination folder exists, and create it if not
$folderPath = "C:\Windows\Temp\packetcapture"
if (-not (Test-Path -Path $folderPath -PathType Container)) {
    New-Item -Path $folderPath -ItemType Directory | Out-Null
}

# Cap the requested size to 50% of free space on the destination drive
$driveLetter = (Get-Item $folderPath).PSDrive.Name
$freeSpaceMB = [math]::Floor((Get-PSDrive -Name $driveLetter).Free / 1MB)
$maxAllowedMB = [math]::Floor($freeSpaceMB * 0.5)

if ($DesiredMaxSizeMB -gt $maxAllowedMB) {
    Write-Warning "Requested $DesiredMaxSizeMB MB exceeds 50% of free space ($maxAllowedMB MB available for use). Capping to $maxAllowedMB MB."
    $maxsize = $maxAllowedMB
}
else {
    $maxsize = $DesiredMaxSizeMB
}

# Set the parameters for Netsh trace
$scenario = "NetConnection"
$capture = "yes"
$report = "yes"
$persistent = "no"
$fileMode = "single"
$correlation = "yes"
$traceFile = "C:\Windows\Temp\packetcapture\packetcapture.etl"
$overwrite = "yes"

# Build the Netsh command
$netshCommand = "Netsh.exe trace start scenario=$scenario capture=$capture report=$report persistent=$persistent maxsize=$maxsize fileMode=$fileMode correlation=$correlation traceFile=$traceFile overwrite=$overwrite"

# Execute the Netsh command
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $netshCommand" -Wait
