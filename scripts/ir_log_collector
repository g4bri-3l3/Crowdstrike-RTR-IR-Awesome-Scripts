###############################################################################################################
###############################################################################################################
#### Script to collect a bundle of IR triage data (event logs, DNS cache, persistence keys, processes). #######
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Collects a bundle of common incident-response triage data from a single host and
    packages it into a zip ready for retrieval via RTR "get".
.DESCRIPTION
    Collects, into a single timestamped folder:
    - System, Security and Application event logs (filtered to the last N hours)
    - Current DNS client cache
    - Common persistence registry keys (Run/RunOnce, both HKLM and HKCU)
    - Running processes with parent PID and command line

    Inspired by the collection approach in https://github.com/happyvives/Windows-IR,
    rewritten here to match this repo's style and to package output as a single zip.

#Credits to happyvives (https://github.com/happyvives/Windows-IR) for the original concept
.PARAMETER HoursBack
    How many hours of event log history to export (default 24). Keep this reasonable -
    full logs can be large and slow to export on noisy hosts.
.PARAMETER OutputPath
    Base folder for collected output (default C:\Windows\Temp\ir_collect).
#>

[CmdletBinding()]
Param (
    [int]$HoursBack = 24,
    [string]$OutputPath = "C:\Windows\Temp\ir_collect"
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$collectFolder = Join-Path $OutputPath $timestamp

if (-not (Test-Path -Path $collectFolder -PathType Container)) {
    New-Item -Path $collectFolder -ItemType Directory -Force | Out-Null
}

$startTime = (Get-Date).AddHours(-$HoursBack)

# Export event logs (System, Security, Application) filtered by time
foreach ($logName in @("System", "Security", "Application")) {
    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName = $logName; StartTime = $startTime } -ErrorAction Stop
        $events | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
            Export-Csv -Path (Join-Path $collectFolder "$logName`_events.csv") -NoTypeInformation
        Write-Host "Exported $($events.Count) events from $logName"
    }
    catch {
        Write-Warning "Unable to export $logName log: $($_.Exception.Message)"
    }
}

# Export current DNS client cache
try {
    Get-DnsClientCache | Select-Object Entry, Name, Data, TimeToLive |
        Export-Csv -Path (Join-Path $collectFolder "dns_cache.csv") -NoTypeInformation
    Write-Host "Exported DNS client cache"
}
catch {
    Write-Warning "Unable to export DNS client cache: $($_.Exception.Message)"
}

# Export common persistence registry keys (Run/RunOnce, HKLM and HKCU)
$runKeyPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)

$runKeyResults = foreach ($path in $runKeyPaths) {
    if (Test-Path $path) {
        $item = Get-ItemProperty -Path $path
        $props = $item.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
        foreach ($p in $props) {
            [PSCustomObject]@{ RegistryPath = $path; ValueName = $p.Name; ValueData = $p.Value }
        }
    }
}

if ($runKeyResults) {
    $runKeyResults | Export-Csv -Path (Join-Path $collectFolder "persistence_run_keys.csv") -NoTypeInformation
    Write-Host "Exported persistence Run/RunOnce keys"
}
else {
    Write-Host "No Run/RunOnce entries found"
}

# Export running processes with parent PID and command line
try {
    Get-CimInstance Win32_Process |
        Select-Object ProcessId, ParentProcessId, Name, CommandLine, CreationDate |
        Export-Csv -Path (Join-Path $collectFolder "running_processes.csv") -NoTypeInformation
    Write-Host "Exported running processes"
}
catch {
    Write-Warning "Unable to export running processes: $($_.Exception.Message)"
}

# Package everything into a single zip for RTR "get"
$zipPath = "$collectFolder.zip"
Compress-Archive -Path "$collectFolder\*" -DestinationPath $zipPath -Force
Remove-Item -Path $collectFolder -Recurse -Force

Write-Host "IR bundle ready at: $zipPath"
Write-Host "Pull it down with the RTR 'get' command: get $zipPath"
