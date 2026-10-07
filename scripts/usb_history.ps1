###############################################################################################################
###############################################################################################################
#### Script to list USB storage devices that have been connected to the host (exfiltration cases). ############
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Exports the history of USB storage devices seen by the host.
.DESCRIPTION
    Read-only. Collects:
    - USBSTOR registry entries (vendor/product, serial, friendly name)
    - Driver framework / PnP events for device connections, when those logs have data
    Output is a zip with CSV files, ready for RTR "get". Registry history persists after the
    device is unplugged; event logs only cover what has not yet rotated out.
.PARAMETER OutputPath
    Base folder for the output (default C:\Windows\Temp\ir_usb).
#>

[CmdletBinding()]
Param (
    [string]$OutputPath = "C:\Windows\Temp\ir_usb"
)

$folder = Join-Path $OutputPath (Get-Date -Format "yyyyMMdd_HHmmss")
New-Item -Path $folder -ItemType Directory -Force | Out-Null

# USBSTOR: one key per device class, one subkey per serial number
$usbstor = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
if (Test-Path $usbstor) {
    $devices = foreach ($class in Get-ChildItem $usbstor -ErrorAction SilentlyContinue) {
        foreach ($inst in Get-ChildItem $class.PSPath -ErrorAction SilentlyContinue) {
            $p = Get-ItemProperty -Path $inst.PSPath -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                DeviceClass  = $class.PSChildName
                SerialNumber = $inst.PSChildName
                FriendlyName = $p.FriendlyName
                Manufacturer = $p.Mfg
                Service      = $p.Service
            }
        }
    }
    if ($devices) {
        $devices | Export-Csv -Path (Join-Path $folder "usbstor_devices.csv") -NoTypeInformation
        Write-Host "Exported $(@($devices).Count) USBSTOR entries"
    }
}
else {
    Write-Host "No USBSTOR key found - no USB storage ever connected."
}

# Connection events (may be disabled or empty on some hosts)
$eventSources = @(
    @{ LogName = "Microsoft-Windows-DriverFrameworks-UserMode/Operational"; Id = 2003, 2100, 2101 },
    @{ LogName = "Microsoft-Windows-Kernel-PnP/Configuration"; Id = 400, 410 }
)
$events = foreach ($src in $eventSources) {
    try {
        Get-WinEvent -FilterHashtable @{ LogName = $src.LogName; Id = $src.Id } -ErrorAction Stop |
            Where-Object { $_.Message -match 'USB' } |
            Select-Object TimeCreated, Id, @{ n = "Log"; e = { $src.LogName } }, Message
    }
    catch {
        Write-Warning "No events from $($src.LogName): $($_.Exception.Message)"
    }
}
if ($events) {
    $events | Export-Csv -Path (Join-Path $folder "usb_events.csv") -NoTypeInformation
    Write-Host "Exported $(@($events).Count) USB-related events"
}

$zipPath = "$folder.zip"
if (Get-ChildItem $folder -File) {
    try {
        Compress-Archive -Path "$folder\*" -DestinationPath $zipPath -Force -ErrorAction Stop
        Remove-Item -Path $folder -Recurse -Force
        Write-Host "USB history ready at: $zipPath"
        Write-Host "Pull it down with the RTR 'get' command: get $zipPath"
    }
    catch {
        Write-Warning "Failed to compress: $($_.Exception.Message). Files left in '$folder'."
    }
}
else {
    Write-Host "Nothing to package."
    Remove-Item -Path $folder -Recurse -Force
}
