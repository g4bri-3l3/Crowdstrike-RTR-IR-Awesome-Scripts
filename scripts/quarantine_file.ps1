###############################################################################################################
###############################################################################################################
#### Script to quarantine a file: archive it with its hash, then remove the original. #########################
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Moves a file into a zip (keeping the evidence) and removes the original.
.DESCRIPTION
    A gentler alternative to file_deleter.ps1. Computes SHA256, writes a small metadata file
    (original path, hash, size, timestamps, who/when), puts both in a zip under the quarantine
    folder, checks the zip really contains the file, and only then deletes the original.
    NOTE: Compress-Archive has no password support - the zip is NOT encrypted, and it holds
    live malware if that is what you quarantined. Handle it accordingly.
.PARAMETER Path
    File to quarantine.
.PARAMETER QuarantineFolder
    Where the zip is stored (default C:\Windows\Temp\ir_quarantine).
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$QuarantineFolder = "C:\Windows\Temp\ir_quarantine"
)

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-Warning "File '$Path' not found."
    return
}

$file = Get-Item -LiteralPath $Path -Force
$hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
New-Item -Path $QuarantineFolder -ItemType Directory -Force | Out-Null

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$workDir = Join-Path $QuarantineFolder "work_$stamp"
New-Item -Path $workDir -ItemType Directory -Force | Out-Null

try {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $workDir $file.Name) -ErrorAction Stop
}
catch {
    Write-Warning "Could not read '$($file.FullName)' (locked by a running process?): $($_.Exception.Message). Nothing was changed."
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
    return
}

@"
OriginalPath : $($file.FullName)
SHA256       : $hash
Length       : $($file.Length)
Created      : $($file.CreationTimeUtc.ToString("o"))
Modified     : $($file.LastWriteTimeUtc.ToString("o"))
Host         : $env:COMPUTERNAME
QuarantinedAt: $((Get-Date).ToUniversalTime().ToString("o"))
RunAs        : $env:USERNAME
"@ | Set-Content -Path (Join-Path $workDir "quarantine_info.txt")

$zipPath = Join-Path $QuarantineFolder "$($hash.Substring(0, 16))_$stamp.zip"
try {
    Compress-Archive -Path "$workDir\*" -DestinationPath $zipPath -Force -ErrorAction Stop

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    $present = $zip.Entries | Where-Object { $_.Name -eq $file.Name }
    $zip.Dispose()
    if (-not $present) { throw "zip does not contain '$($file.Name)'" }

    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
    Write-Host "Quarantined '$($file.FullName)' (SHA256 $hash)"
    Write-Host "Archive: $zipPath"
    Write-Host "Pull it down with the RTR 'get' command: get $zipPath"
}
catch {
    Write-Warning "Quarantine failed: $($_.Exception.Message). The original file was left in place."
}
finally {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}
