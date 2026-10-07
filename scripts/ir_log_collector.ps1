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
    - Scheduled tasks, non-Microsoft services, WMI event subscriptions, Startup folder contents
    - PowerShell console history of every user profile
    - PowerShell ScriptBlock logging events (4104), if logging is enabled on the host

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

# Scheduled tasks (name, state, author, actions)
try {
    Get-ScheduledTask -ErrorAction Stop | ForEach-Object {
        [PSCustomObject]@{
            TaskPath = $_.TaskPath
            TaskName = $_.TaskName
            State    = $_.State
            Author   = $_.Author
            RunAs    = $_.Principal.UserId
            Actions  = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)".Trim() }) -join " ; "
        }
    } | Export-Csv -Path (Join-Path $collectFolder "scheduled_tasks.csv") -NoTypeInformation
    Write-Host "Exported scheduled tasks"
}
catch {
    Write-Warning "Unable to export scheduled tasks: $($_.Exception.Message)"
}

# Services whose binary lives outside C:\Windows (a quick way to spot third-party/rogue services)
try {
    Get-CimInstance Win32_Service |
        Where-Object { $_.PathName -and $_.PathName -notmatch '^"?[A-Za-z]:\\Windows\\' } |
        Select-Object Name, DisplayName, State, StartMode, StartName, PathName |
        Export-Csv -Path (Join-Path $collectFolder "non_microsoft_services.csv") -NoTypeInformation
    Write-Host "Exported non-Windows-path services"
}
catch {
    Write-Warning "Unable to export services: $($_.Exception.Message)"
}

# WMI event subscriptions (classic fileless persistence)
try {
    $wmiOut = foreach ($class in "__EventFilter", "__EventConsumer", "__FilterToConsumerBinding") {
        Get-CimInstance -Namespace "root\subscription" -ClassName $class -ErrorAction Stop |
            ForEach-Object { [PSCustomObject]@{ Class = $class; Details = ($_ | Format-List * | Out-String).Trim() } }
    }
    if ($wmiOut) {
        $wmiOut | Export-Csv -Path (Join-Path $collectFolder "wmi_subscriptions.csv") -NoTypeInformation
        Write-Host "Exported WMI subscriptions"
    }
    else {
        Write-Host "No WMI subscriptions found"
    }
}
catch {
    Write-Warning "Unable to export WMI subscriptions: $($_.Exception.Message)"
}

# Startup folders (all users + each user profile)
$startupPaths = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup") +
    (Get-ChildItem "C:\Users" -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
    })
$startupItems = foreach ($p in $startupPaths) {
    if (Test-Path $p) {
        Get-ChildItem -Path $p -File -Force -ErrorAction SilentlyContinue |
            Select-Object FullName, Length, CreationTime, LastWriteTime
    }
}
if ($startupItems) {
    $startupItems | Export-Csv -Path (Join-Path $collectFolder "startup_folders.csv") -NoTypeInformation
    Write-Host "Exported Startup folder contents"
}
else {
    Write-Host "No Startup folder items found"
}

# PowerShell console history for every user profile
$psHistoryFolder = Join-Path $collectFolder "ps_history"
Get-ChildItem "C:\Users" -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $hist = Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    if (Test-Path $hist) {
        New-Item -Path $psHistoryFolder -ItemType Directory -Force | Out-Null
        Copy-Item -Path $hist -Destination (Join-Path $psHistoryFolder "$($_.Name)_ConsoleHost_history.txt") -ErrorAction SilentlyContinue
        Write-Host "Copied PowerShell history for $($_.Name)"
    }
}

# PowerShell ScriptBlock logging events (4104) - empty unless logging is enabled on the host
try {
    $sbEvents = Get-WinEvent -FilterHashtable @{ LogName = "Microsoft-Windows-PowerShell/Operational"; Id = 4104; StartTime = $startTime } -ErrorAction Stop
    $sbEvents | Select-Object TimeCreated, Id, UserId, Message |
        Export-Csv -Path (Join-Path $collectFolder "powershell_4104_events.csv") -NoTypeInformation
    Write-Host "Exported $($sbEvents.Count) ScriptBlock (4104) events"
}
catch {
    Write-Warning "No 4104 events exported: $($_.Exception.Message)"
}

# Package everything into a single zip for RTR "get"
$zipPath = "$collectFolder.zip"
try {
    Compress-Archive -Path "$collectFolder\*" -DestinationPath $zipPath -Force -ErrorAction Stop
    if (Test-Path -Path $zipPath) {
        Remove-Item -Path $collectFolder -Recurse -Force
        Write-Host "IR bundle ready at: $zipPath"
        Write-Host "Pull it down with the RTR 'get' command: get $zipPath"
    }
    else {
        Write-Warning "Compress-Archive did not report an error, but '$zipPath' was not found. Leaving raw files in '$collectFolder' rather than deleting them."
    }
}
catch {
    Write-Warning "Failed to compress collected data: $($_.Exception.Message). Leaving raw files in '$collectFolder' rather than deleting them."
}
