###############################################################################################################
###############################################################################################################
#### Script to audit Microsoft Defender exclusions (attackers love adding them). ##############################
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Lists Microsoft Defender exclusions (paths, processes, extensions, IPs) and key settings.
.DESCRIPTION
    Read-only. Prints the effective exclusions from Get-MpPreference and, separately, the
    ones set in the local registry and by policy, so a manual tweak can be told apart from a
    GPO/Intune one. Also reports whether real-time protection is disabled.
    Output goes to the console (RTR returns it directly); nothing is changed.
#>

[CmdletBinding()]
Param ()

try {
    $pref = Get-MpPreference -ErrorAction Stop
}
catch {
    Write-Warning "Get-MpPreference failed (Defender not installed or replaced by another AV?): $($_.Exception.Message)"
    return
}

Write-Host "Host: $env:COMPUTERNAME"
Write-Host "RealTimeProtectionDisabled: $($pref.DisableRealtimeMonitoring)"
Write-Host "BehaviorMonitoringDisabled: $($pref.DisableBehaviorMonitoring)"
Write-Host "IOAVProtectionDisabled:     $($pref.DisableIOAVProtection)"
Write-Host ""

$effective = @(
    $pref.ExclusionPath      | ForEach-Object { [PSCustomObject]@{ Type = "Path";      Value = $_ } }
    $pref.ExclusionProcess   | ForEach-Object { [PSCustomObject]@{ Type = "Process";   Value = $_ } }
    $pref.ExclusionExtension | ForEach-Object { [PSCustomObject]@{ Type = "Extension"; Value = $_ } }
    $pref.ExclusionIpAddress | ForEach-Object { [PSCustomObject]@{ Type = "IP";        Value = $_ } }
) | Where-Object { $_.Value }

if ($effective) {
    Write-Host "Effective exclusions ($(@($effective).Count)):"
    $effective | Format-Table -AutoSize | Out-String | Write-Host
}
else {
    Write-Host "No effective exclusions (or hidden from this context)."
}

# Where do they come from? Local registry vs policy.
$sources = @{
    "Local"  = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions"
    "Policy" = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions"
}
foreach ($label in $sources.Keys) {
    $base = $sources[$label]
    if (-not (Test-Path $base)) { continue }
    foreach ($sub in Get-ChildItem $base -ErrorAction SilentlyContinue) {
        $names = (Get-Item $sub.PSPath).Property | Where-Object { $_ -and $_ -ne "(default)" }
        foreach ($n in $names) { Write-Host ("[{0}] {1}: {2}" -f $label, $sub.PSChildName, $n) }
    }
}
