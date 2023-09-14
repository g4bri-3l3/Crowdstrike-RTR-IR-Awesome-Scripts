###############################################################################################################
###############################################################################################################
#### Script to dump the memory on a host (file will go up to 1Gb). ############################################
###############################################################################################################
###############################################################################################################

# Set the parameters for Netsh trace
$scenario = "NetConnection"
$capture = "yes"
$report = "yes"
$persistent = "no"
$maxsize = 1000
$fileMode = "single"
$correlation = "yes"
$traceFile = "C:\Windows\Temp\packetcapture\packetcapture.etl"
$overwrite = "yes"

# Check if the destination folder exists, and create it if not
$folderPath = "C:\Windows\Temp\packetcapture"
if (-not (Test-Path -Path $folderPath -PathType Container)) {
    New-Item -Path $folderPath -ItemType Directory
}

# Build the Netsh command
$netshCommand = "Netsh.exe trace start scenario=$scenario capture=$capture report=$report persistent=$persistent maxsize=$maxsize fileMode=$fileMode correlation=$correlation traceFile=$traceFile overwrite=$overwrite"

# Execute the Netsh command
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $netshCommand" -Wait
