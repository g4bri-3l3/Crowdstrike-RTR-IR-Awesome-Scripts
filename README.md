# What

A list of curated Powershell scripts to be used with Crowdstrike Falcon Real Time Response (but you can use them with any EDR/tool that permit you to deploy .ps1 scripts).
Some useful scripts to use in incident response.

# Links

- [Stolen Device Wiper](https://github.com/g4bri-3l3/Crowdstrike-RTR-Awesome-Scripts/blob/main/scripts/stolen_device_wiper.ps1)
Leveraging Bitlocker keys to immediately lock an endpoint (you will have in output the new key).

- [Chrome Extensions Lister ](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/chrome_extensions_lister.ps1)
List all Chrome Extensions and optionally upload the hash to VirusTotal

- [Terminated User Handle](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/terminated_user_handle.ps1)
When a user is terminated, handle it by immediately removing the session on the host, changing local passwords, Kerberos keys, etc.

- [Local Admin Creator](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/create_local_admin.ps1)
A simple script to create a local admin user on the host. Useful in case you have lost access to the endpoint.

- [File Deleter](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/file_deleter.ps1)
Delete files based on various parameters. Can be useful when you are in a hurry in incident response or maybe handling an internal error (for instance a member of some finance staff wrongly sent a private document)  ;)

# Suggested Usage


***For a host***

Invoke-FalconRtr -Command runscript -Argument "-Cloudfile='the_script'" -CommandLine="the_arguments" -HostId 'the_host_id' -Timeout 600 -QueueOffline $true (set the timeout for the script and put in queue in case the host is currently offline)

***For a group of hosts***

**Get the group id**

$GroupName = 'SDB - Edge Workstations'.ToLower()
$Id = Get-FalconHostGroup -Filter "name:'$GroupName'"

Invoke-FalconRtr -Command runscript -Argument "-Cloudfile='the_script'" -CommandLine="the_arguments" -Groupid 'the_group_id' -Timeout 600 -QueueOffline $true (set the timeout for the script and put in queue in case the host is currently offline)
