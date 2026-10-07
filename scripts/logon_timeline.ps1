###############################################################################################################
###############################################################################################################
#### Script to build a logon/RDP timeline (useful to spot lateral movement). ##################################
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Exports a normalized CSV of logon and RDP activity for the last N hours.
.DESCRIPTION
    Collects, and flattens into one CSV (time, event id, user, source IP, logon type, ...):
    - Security 4624 (logon), 4625 (failed logon), 4648 (explicit credentials)
    - Security 4778/4779 (RDP session reconnect/disconnect)
    - TerminalServices RemoteConnectionManager 1149 and LocalSessionManager 21/22/24/25
    The result is zipped, ready for RTR "get". Security events need admin/SYSTEM.
.PARAMETER HoursBack
    How many hours of history to read (default 72).
.PARAMETER OutputPath
    Base folder for the output (default C:\Windows\Temp\ir_logons).
#>

[CmdletBinding()]
Param (
    [int]$HoursBack = 72,
    [string]$OutputPath = "C:\Windows\Temp\ir_logons"
)

$logonTypes = @{
    2 = "Interactive"; 3 = "Network"; 4 = "Batch"; 5 = "Service"; 7 = "Unlock"
    8 = "NetworkCleartext"; 9 = "NewCredentials"; 10 = "RemoteInteractive"; 11 = "CachedInteractive"
}

$startTime = (Get-Date).AddHours(-$HoursBack)
$sources = @(
    @{ LogName = "Security"; Id = 4624, 4625, 4648, 4778, 4779 },
    @{ LogName = "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational"; Id = 1149 },
    @{ LogName = "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"; Id = 21, 22, 24, 25 }
)

$rows = foreach ($src in $sources) {
    $filter = @{ LogName = $src.LogName; Id = $src.Id; StartTime = $startTime }
    try {
        $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
    }
    catch {
        Write-Warning "Skipping $($src.LogName): $($_.Exception.Message)"
        continue
    }

    foreach ($ev in $events) {
        $xml = [xml]$ev.ToXml()
        $d = @{}
        foreach ($n in @($xml.Event.EventData.Data)) { if ($n.Name) { $d[$n.Name] = $n.'#text' } }
        if ($xml.Event.UserData) {
            foreach ($n in $xml.Event.UserData.FirstChild.ChildNodes) { $d[$n.LocalName] = $n.InnerText }
        }

        $user = $null; $ip = $null; $type = $null; $host_ = $null
        switch ($ev.Id) {
            { $_ -in 4624, 4625 } {
                $user = "$($d.TargetDomainName)\$($d.TargetUserName)"; $ip = $d.IpAddress; $host_ = $d.WorkstationName
                $type = if ($logonTypes.ContainsKey([int]$d.LogonType)) { $logonTypes[[int]$d.LogonType] } else { $d.LogonType }
            }
            4648 { $user = "$($d.TargetDomainName)\$($d.TargetUserName)"; $ip = $d.IpAddress; $host_ = $d.TargetServerName; $type = "ExplicitCreds (by $($d.SubjectUserName))" }
            { $_ -in 4778, 4779 } { $user = "$($d.AccountDomain)\$($d.AccountName)"; $ip = $d.ClientAddress; $host_ = $d.ClientName; $type = "RDP session" }
            1149 { $user = "$($d.Param2)\$($d.Param1)"; $ip = $d.Param3; $type = "RDP auth success" }
            default { $user = $d.User; $ip = $d.Address; $type = "RDP session ($($d.Action))" }
        }

        [PSCustomObject]@{
            TimeCreated = $ev.TimeCreated
            EventId     = $ev.Id
            Log         = $src.LogName.Split('-')[-1].Split('/')[0]
            User        = $user
            SourceIP    = $ip
            SourceHost  = $host_
            LogonType   = $type
        }
    }
}

if (-not $rows) {
    Write-Warning "No matching events found in the last $HoursBack hours."
    return
}

$folder = Join-Path $OutputPath (Get-Date -Format "yyyyMMdd_HHmmss")
New-Item -Path $folder -ItemType Directory -Force | Out-Null
$csv = Join-Path $folder "logon_timeline.csv"
$rows | Sort-Object TimeCreated | Export-Csv -Path $csv -NoTypeInformation
Write-Host "Exported $(@($rows).Count) events"

$zipPath = "$folder.zip"
try {
    Compress-Archive -Path $csv -DestinationPath $zipPath -Force -ErrorAction Stop
    Remove-Item -Path $folder -Recurse -Force
    Write-Host "Timeline ready at: $zipPath"
    Write-Host "Pull it down with the RTR 'get' command: get $zipPath"
}
catch {
    Write-Warning "Failed to compress: $($_.Exception.Message). CSV left in '$folder'."
}
