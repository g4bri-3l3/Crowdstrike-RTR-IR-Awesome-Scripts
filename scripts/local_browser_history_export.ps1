###############################################################################################################
###############################################################################################################
#### Script to export local browser history for Chrome and Edge ###############################################
###############################################################################################################
###############################################################################################################

# Set ErrorActionPreference to SilentlyContinue to suppress errors
$ErrorActionPreference = 'SilentlyContinue'

# Print information about script usage
Write-Host '-------------------------'
Write-Host 'BE SURE TO ADD -Timeout=600 in the runscript options before you run this script'
Write-Host 'Example:'
Write-Host 'runscript -CloudFile="Browser_History_Hindsight" -Timeout=600'
Write-Host '-------------------------'
Write-Host "[+] INFO: Fetching Latest 4 Users Chrome, Edge History"

# Stop any existing 'hindsight' processes
Stop-Process -Name hindsight -Force

# Create a temporary directory if it doesn't exist
$tempDir = 'C:\windows\Temp\ftech_temp'
if (-not (Test-Path -Path $tempDir -PathType Container)) {
    New-Item -Path $tempDir -ItemType Directory | Out-Null
}

# Download the hindsight.exe tool
$downloadUrl = 'https://github.com/obsidianforensics/hindsight/releases/download/v2021.12/hindsight.exe'
Invoke-WebRequest -Uri $downloadUrl -OutFile "$tempDir\hindsight.exe"

# Loop through the top 4 recent user directories
$recentUserDirs = Get-ChildItem -Directory -Path 'C:\Users\' -ErrorAction SilentlyContinue -Force |
    Sort-Object LastWriteTime -Descending | Select-Object -First 4

foreach ($userDir in $recentUserDirs) {
    $userName = $userDir.Name
    Write-Host "[+] INFO: Dumping $userName MSEdge/Chrome"
    
    # Create directories for Chrome and Edge data
    New-Item -Path "$tempDir\$userName Chrome" -ItemType Directory | Out-Null
    New-Item -Path "$tempDir\$userName Edge" -ItemType Directory | Out-Null
    
    # Run hindsight.exe for Edge
    Start-Process -FilePath "$tempDir\hindsight.exe" -ArgumentList "-i `"C:\Users\$userName\AppData\Local\Microsoft\Edge\User Data\Default`" -o `"C:\windows\Temp\ftech_temp\$userName Edge`"" -WorkingDirectory "$tempDir\$userName Edge" -Verbose -WindowStyle Hidden

    # Run hindsight.exe for Chrome
    Start-Process -FilePath "$tempDir\hindsight.exe" -ArgumentList "-i `"C:\Users\$userName\AppData\Local\Google\Chrome\User Data\Default`" -o `"C:\windows\Temp\ftech_temp\$userName Chrome`"" -WorkingDirectory "$tempDir\$userName Chrome" -Verbose -WindowStyle Hidden
}

Write-Host "[+] INFO: Waiting up to 5 minutes for Hindsight to complete"
# Wait for the hindsight processes to complete (timeout 300 seconds)
Wait-Process -Name hindsight -Timeout 300

# Get Excel files in the temporary directory
$excelFiles = Get-ChildItem -Path $tempDir -Filter *.xlsx

# Compress Excel files into a zip archive
$zipFilePath = 'C:\windows\Temp\ftech_temp\hindsight.zip'
$excelFiles | Compress-Archive -DestinationPath $zipFilePath -Force

# Print instructions for viewing and cleaning up
Write-Host "Type the following command to view the contents of the zip file:"
Write-Host "Get-Content $zipFilePath"
Write-Host "Password is infected. When the download is complete, type:"
Write-Host "Remove-Item $tempDir -Force"
