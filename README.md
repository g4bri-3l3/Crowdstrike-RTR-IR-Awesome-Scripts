# What

A list of curated Powershell scripts to be used with Crowdstrike Falcon Real Time Response (but with any tool that permit you to deploy .ps1 scripts).

# Suggested Usage

Invoke-FalconRtr -Command runscript -Argument "-Cloudfile='the_script'" -HostId 'the_host_id' -Timeout 600 -QueueOffline $true (set the timeout for the script and put in queue in case the host is currently offline)
