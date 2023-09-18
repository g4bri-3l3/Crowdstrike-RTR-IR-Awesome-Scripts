# What

A list of curated Powershell scripts to be used with Crowdstrike Falcon Real Time Response/Fusion Workflows/PSFalcon (but you can use them with any EDR/SOAR/tool that permit you to deploy .ps1 scripts) to be used in (not only) incident response.

# Docs

https://falcon.eu-1.crowdstrike.com/documentation/page/faa65a8c/falcon-fusion-playbooks
https://www.crowdstrike.com/blog/how-to-defend-against-threats-with-falcon-fusion-and-falcon-real-time-response/


# Scripts

- [Stolen Device Wiper](https://github.com/g4bri-3l3/Crowdstrike-RTR-Awesome-Scripts/blob/main/scripts/stolen_device_wiper.ps1)
Leveraging Bitlocker keys to immediately lock an endpoint (you will have in output the new key).

- [Chrome Extensions Lister ](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/chrome_extensions_lister.ps1)
List all Chrome Extensions and optionally upload the hash to VirusTotal.

- [Terminated User Handle](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/terminated_user_handle.ps1)
When a user is terminated, handle it by immediately removing the session on the host, changing local passwords, Kerberos keys, etc.

- [Local Admin Creator](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/create_local_admin.ps1)
A simple script to create a local admin user on the host. Useful in case you have lost access to the endpoint.
Example usage: ".\create_local_admin.ps1 -Username "tempadmin" -Password "YourPassword" -FullName "Temp Admin" -Description "Temporary admin user"

- [File Deleter](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/file_deleter.ps1)
Delete files based on various parameters. Can be useful when you are in a hurry in incident response or maybe handling an internal error (for instance a member of finance staff wrongly sent a private document ;).
Example usage: ".\file_deleter.ps1 -NumSearchStrings 2 -SearchStrings "string1", "string2" -DirectoryPath "C:\Users\""

- [Memory dumper](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/memdump.ps1)
Dump the memory via netsh command.

- [Local Browser History Export](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/local_browser_history_export.ps1)
Export local browser history in a fancy way (Chrome and Edge supported).

# Suggested Usage

****With PSFalcon:****

***For a host***

Invoke-FalconRtr -Command runscript -Argument "-Cloudfile='the_script'" -CommandLine="the_arguments" -HostId 'the_host_id' -Timeout 600 -QueueOffline $true (set the timeout for the script and put in queue in case the host is currently offline)

***For a group of hosts***

***To get the group id***

$GroupName = 'Workstations'.ToLower()
$Id = Get-FalconHostGroup -Filter "name:'$GroupName'"

Invoke-FalconRtr -Command runscript -Argument "-Cloudfile='the_script'" -CommandLine="the_arguments" -Groupid 'the_group_id' -Timeout 600 -QueueOffline $true (set the timeout for the script and put in queue in case the host is currently offline)


****With Fusion Workflows****

Upload the script and mark it as available in Fusion:

![image](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/assets/46595230/bb1f92d3-c6b1-43ac-bb52-94e159935983)

And then leverage it in the Workflow:

![image](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/assets/46595230/0a0dff6e-3e07-4d0a-9a60-ea12830c195a)


****With an automation tool such as Tines****

Just leverage Tines and send the command via RTR:

![image](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/assets/46595230/b494263d-8d31-4e89-9692-dc10c80b48b1)

