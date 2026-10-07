###############################################################################################################
###############################################################################################################
#### Script to stop the capture started by netdump.ps1 and package it for RTR "get". ##########################
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Stops the netsh trace started by netdump.ps1 and zips the result for retrieval.
.DESCRIPTION
    Runs "netsh trace stop" (this can take a while on large captures, so use a generous
    RTR -Timeout), then compresses the .etl/.cab files in the capture folder into a single
    zip. The raw files are only deleted if the zip was created successfully.
.PARAMETER CaptureFolder
    Folder used by netdump.ps1 (default C:\Windows\Temp\packetcapture).
#>

[CmdletBinding()]
Param (
    [string]$CaptureFolder = "C:\Windows\Temp\packetcapture"
)

# Stop the trace. A non-zero exit code usually means no trace was running.
$stopOutput = netsh trace stop 2>&1
$stopOutput | Out-String | Write-Host
if ($LASTEXITCODE -ne 0) {
    Write-Warning "netsh trace stop returned $LASTEXITCODE - no active trace? Will still try to package any existing files."
}

if (-not (Test-Path -Path $CaptureFolder -PathType Container)) {
    Write-Warning "Capture folder '$CaptureFolder' not found. Nothing to package."
    return
}

$files = Get-ChildItem -Path $CaptureFolder -File -Include *.etl, *.cab -Recurse -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Warning "No .etl/.cab files found in '$CaptureFolder'."
    return
}

$zipPath = Join-Path (Split-Path $CaptureFolder -Parent) ("packetcapture_{0}.zip" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
try {
    Compress-Archive -Path $files.FullName -DestinationPath $zipPath -Force -ErrorAction Stop
    if (Test-Path -Path $zipPath) {
        $files | Remove-Item -Force
        Write-Host "Capture ready at: $zipPath"
        Write-Host "Pull it down with the RTR 'get' command: get $zipPath"
    }
    else {
        Write-Warning "Zip '$zipPath' was not found after compression. Raw files left in '$CaptureFolder'."
    }
}
catch {
    Write-Warning "Failed to compress capture: $($_.Exception.Message). Raw files left in '$CaptureFolder'."
}
