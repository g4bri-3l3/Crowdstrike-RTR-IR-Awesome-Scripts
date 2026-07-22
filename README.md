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

- [Memory dumper](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/netdump.ps1)
Dump the network traffic via netsh command.

- [Local Browser History Export](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/local_browser_history_export.ps1)
Export local browser history in a fancy way (Chrome and Edge supported).

- [AI Alert Triage](https://github.com/g4bri-3l3/Crowdstrike-RTR-IR-Awesome-Scripts/blob/main/scripts/ai_alert_triage.ps1)
Sends RTR-collected telemetry (process list, netstat, parent-process chain, etc.) to an LLM (Gemini by default) and returns a plain-English summary, a likely MITRE ATT&CK mapping, a suggested severity, and a suggested next step. Decision support only - no containment action is taken automatically, an analyst must review the output before acting on it.
Example usage: ". .\ai_alert_triage.ps1" then "$ps = Invoke-FalconRtr -Command ps -HostId $hostId" then "Invoke-AITriage -Telemetry ($ps | Out-String)"

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

# AI-Assisted Triage

`ai_alert_triage.ps1` sends RTR-collected telemetry (process list, netstat, parent-process chain, etc.) to an LLM (Gemini by default) and returns a quick summary, a likely MITRE ATT&CK mapping, a suggested severity, and a suggested next step.

This is a lightweight, direct-REST take on the same idea behind CrowdStrike's official [falcon-mcp](https://github.com/CrowdStrike/falcon-mcp) - an MCP server that exposes Falcon detections, threat intel, and host management to AI agents. `falcon-mcp` is the more complete, officially supported path if you need broader Falcon API coverage or multi-tool agent workflows; this script stays intentionally minimal for single-purpose telemetry triage.

****This is decision support only.**** No containment action is taken automatically - no host isolation, no process kill, no account changes. An analyst must review the output before acting on it.

***Setup***

$env:GEMINI_API_KEY = "..."
. .\ai_alert_triage.ps1

***Usage***

$ps = Invoke-FalconRtr -Command ps -HostId $hostId
$result = Invoke-AITriage -Telemetry ($ps | Out-String)
$result | Format-List

Works with any text blob from RTR/PSFalcon (process list, netstat output, registry run keys, etc.) - not just `ps`.

***Known limitations***

- **Telemetry is untrusted input.** Command lines, file names, and other fields in the collected telemetry are attacker-controlled data, not sanitized text. A crafted process command line could contain instructions aimed at the LLM itself (e.g. text designed to make the model under-rate severity or suggest no action). Treat every field in the telemetry blob as potentially adversarial, the same way you would with any other attacker-supplied string in an IR pipeline.
- **Mitigations already in place:** the script never executes anything automatically (decision support only), and the system prompt explicitly instructs the model to prefer a lower-confidence, human-review-first framing when evidence is ambiguous.
- **Mitigations to consider adding:** logging the raw telemetry alongside the model's output for later audit, and/or a basic pre-filter that flags telemetry containing suspicious phrases (e.g. "ignore previous instructions") for extra analyst scrutiny before trusting the triage result.
