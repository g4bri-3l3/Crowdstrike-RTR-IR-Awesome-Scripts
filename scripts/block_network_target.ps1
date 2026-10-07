###############################################################################################################
###############################################################################################################
#### Script to block (or unblock) an IP/CIDR/domain with Windows Firewall as targeted containment. ############
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Adds Windows Firewall block rules for specific IPs, CIDR ranges or domains, with easy rollback.
.DESCRIPTION
    Creates inbound + outbound block rules named "IRBlock_<target>" so they are easy to find.
    Domains are resolved to IPs at the moment the script runs - if the domain's IPs change
    later, the rule will not follow them. Use -Remove to roll back one target, or all
    IRBlock_* rules if no target is given. Use it when you want to cut a specific C2 channel
    without isolating the whole host.
.PARAMETER Target
    One or more IPv4/IPv6 addresses, CIDR ranges or domain names.
.PARAMETER Remove
    Remove the rules instead of creating them.
.EXAMPLE
    .\block_network_target.ps1 -Target "203.0.113.7","evil.example.com"
.EXAMPLE
    .\block_network_target.ps1 -Remove
#>

[CmdletBinding()]
Param (
    [string[]]$Target,
    [switch]$Remove
)

$prefix = "IRBlock_"

if ($Remove) {
    $rules = if ($Target) {
        $Target | ForEach-Object { Get-NetFirewallRule -DisplayName "$prefix$_*" -ErrorAction SilentlyContinue }
    }
    else {
        Get-NetFirewallRule -DisplayName "$prefix*" -ErrorAction SilentlyContinue
    }
    if (-not $rules) { Write-Host "No matching $prefix rules found."; return }
    $rules | ForEach-Object { Write-Host "Removing rule '$($_.DisplayName)'" }
    $rules | Remove-NetFirewallRule
    return
}

if (-not $Target) {
    Write-Warning "No -Target given. Nothing to do."
    return
}

foreach ($t in $Target) {
    $addresses = @()
    $isIp = $t -match '^[0-9a-fA-F:\.]+(/\d{1,3})?$' -and [ipaddress]::TryParse(($t -split '/')[0], [ref]$null)

    if ($isIp) {
        $addresses = @($t)
    }
    else {
        try {
            $addresses = Resolve-DnsName -Name $t -Type A_AAAA -ErrorAction Stop |
                Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique
        }
        catch {
            Write-Warning "Could not resolve '$t': $($_.Exception.Message). Skipping."
            continue
        }
        if (-not $addresses) { Write-Warning "'$t' resolved to no addresses. Skipping."; continue }
    }

    foreach ($dir in "Outbound", "Inbound") {
        $name = "$prefix${t}_$dir"
        if (Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $name
        }
        try {
            New-NetFirewallRule -DisplayName $name -Direction $dir -Action Block -RemoteAddress $addresses `
                -Profile Any -Description "IR containment block created $(Get-Date -Format s)" -ErrorAction Stop | Out-Null
            Write-Host "Blocked $dir traffic for '$t' ($($addresses -join ', '))"
        }
        catch {
            Write-Warning "Failed to create $dir rule for '$t': $($_.Exception.Message)"
        }
    }
}
