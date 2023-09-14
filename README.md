# What

A list of curated Powershell scripts to be used with Crowdstrike Falcon Real Time Response (but you can use them with any EDR/tool that permit you to deploy .ps1 scripts).
Some useful scripts to use in incident response.

#Links

- Stolen Device Wiper -
Leveraging Bitlocker keys to immediately lock an endpoint (you will have in output the new key).
[Stolen Device Wiper](https://github.com/g4bri-3l3/Crowdstrike-RTR-Awesome-Scripts/blob/main/scripts/stolen_device_wiper.ps1)

# Suggested Usage

Invoke-FalconRtr -Command runscript -Argument "-Cloudfile='the_script'" -HostId 'the_host_id' -Timeout 600 -QueueOffline $true (set the timeout for the script and put in queue in case the host is currently offline)
