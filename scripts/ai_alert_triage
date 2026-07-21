<#
.SYNOPSIS
    AI-assisted enrichment/triage for CrowdStrike RTR / incident response data.

.DESCRIPTION
    Takes host/process telemetry already collected via RTR (e.g. output of
    `ps`, `netstat`, or a parent-process chain pulled with PSFalcon) and sends
    it to an LLM (Google Gemini by default) to obtain:
      - a plain-English summary of what's happening
      - the most likely MITRE ATT&CK technique(s)
      - a suggested severity (Informational/Low/Medium/High/Critical)
      - a suggested next IR action

    DECISION SUPPORT ONLY. This script takes no containment action itself
    (no isolation, no process kill, no account disable). An analyst must
    review the output before acting on it - treat it as a second opinion,
    not a verdict.

.PARAMETER Telemetry
    Raw text blob of RTR output to analyze (process list, netstat, etc.)

.PARAMETER ApiKey
    Gemini API key. Defaults to $env:GEMINI_API_KEY.

.PARAMETER Model
    Gemini model name. Defaults to gemini-2.0-flash.

.EXAMPLE
    . .\ai_alert_triage.ps1
    $ps = Invoke-FalconRtr -Command ps -HostId $hostId
    Invoke-AITriage -Telemetry ($ps | Out-String)
#>

function Invoke-AITriage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Telemetry,

        [Parameter(Mandatory = $false)]
        [string]$ApiKey = $env:GEMINI_API_KEY,

        [Parameter(Mandatory = $false)]
        [string]$Model = "gemini-2.0-flash"
    )

    if (-not $ApiKey) {
        throw "No API key provided. Set `$env:GEMINI_API_KEY or pass -ApiKey."
    }

    $systemPrompt = @"
You are a SOC triage assistant. You are given raw host/process telemetry
collected during incident response via CrowdStrike RTR. Analyze it and
respond with a single JSON object only, no markdown fences, matching this
schema:

{
  "summary": "plain-English summary of the observed activity",
  "mitre_technique": "most relevant ATT&CK technique ID + name, or null",
  "severity": "Informational | Low | Medium | High | Critical",
  "recommended_action": "suggested next IR step",
  "confidence": "Low | Medium | High"
}

This is decision support only, never a final verdict. Never claim certainty
you don't have - when the evidence is ambiguous, say so explicitly and
prefer a lower confidence, human-review-first framing over a confident
guess.
"@

    $bodyObj = @{
        system_instruction = @{ parts = @(@{ text = $systemPrompt }) }
        contents           = @(@{ role = "user"; parts = @(@{ text = $Telemetry }) })
        generationConfig   = @{ temperature = 0.2 }
    }
    $body = $bodyObj | ConvertTo-Json -Depth 10

    $uri = "https://generativelanguage.googleapis.com/v1beta/models/${Model}:generateContent?key=$ApiKey"

    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
    $rawText = $response.candidates[0].content.parts[0].text

    try {
        return $rawText | ConvertFrom-Json
    }
    catch {
        Write-Warning "Model did not return clean JSON. Returning raw text instead."
        return $rawText
    }
}

# Example (commented out):
# . .\ai_alert_triage.ps1
# $ps = Invoke-FalconRtr -Command ps -HostId $hostId
# $result = Invoke-AITriage -Telemetry ($ps | Out-String)
# $result | Format-List
