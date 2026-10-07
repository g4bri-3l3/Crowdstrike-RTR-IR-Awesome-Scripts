###############################################################################################################
###############################################################################################################
#### Script to find unsigned executables in user-writable paths. ##############################################
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Lists unsigned/invalidly signed executables in locations where users (and malware) can write.
.DESCRIPTION
    Scans AppData, Windows\Temp, ProgramData and Users\Public for exe/dll/scr/com files,
    checks the Authenticode signature, and exports every file that is NOT validly signed
    with its SHA256. Read-only: nothing is deleted or moved. Unsigned does not mean
    malicious (plenty of legit software is unsigned) - treat the CSV as a lead list.
.PARAMETER DaysBack
    Only consider files modified in the last N days (default 30, 0 = no limit; a full scan
    can be slow, so raise the RTR -Timeout).
.PARAMETER Extensions
    File extensions to check (default exe, dll, scr, com).
.PARAMETER OutputPath
    Base folder for the output (default C:\Windows\Temp\ir_binaries).
#>

[CmdletBinding()]
Param (
    [int]$DaysBack = 30,
    [string[]]$Extensions = @("exe", "dll", "scr", "com"),
    [string]$OutputPath = "C:\Windows\Temp\ir_binaries"
)

$roots = @("C:\Windows\Temp", "C:\ProgramData", "C:\Users\Public") +
    (Get-ChildItem "C:\Users" -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName "AppData" })
$roots = $roots | Where-Object { Test-Path $_ }

$include = $Extensions | ForEach-Object { "*.$_" }
$cutoff = if ($DaysBack -gt 0) { (Get-Date).AddDays(-$DaysBack) } else { [datetime]::MinValue }

$results = foreach ($root in $roots) {
    Write-Host "Scanning $root"
    Get-ChildItem -Path $root -Recurse -File -Include $include -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $cutoff } |
        ForEach-Object {
            $sig = Get-AuthenticodeSignature -FilePath $_.FullName -ErrorAction SilentlyContinue
            if ($sig -and $sig.Status -eq "Valid") { return }
            [PSCustomObject]@{
                Path          = $_.FullName
                Length        = $_.Length
                LastWriteTime = $_.LastWriteTime
                SigStatus     = if ($sig) { $sig.Status } else { "Unknown" }
                Signer        = if ($sig -and $sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { $null }
                SHA256        = (Get-FileHash -Path $_.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
            }
        }
}

if (-not $results) {
    Write-Host "No unsigned/invalid binaries found in the scanned paths."
    return
}

$folder = Join-Path $OutputPath (Get-Date -Format "yyyyMMdd_HHmmss")
New-Item -Path $folder -ItemType Directory -Force | Out-Null
$csv = Join-Path $folder "unsigned_binaries.csv"
$results | Sort-Object LastWriteTime -Descending | Export-Csv -Path $csv -NoTypeInformation
Write-Host "Found $(@($results).Count) unsigned/invalid binaries"

$zipPath = "$folder.zip"
try {
    Compress-Archive -Path $csv -DestinationPath $zipPath -Force -ErrorAction Stop
    Remove-Item -Path $folder -Recurse -Force
    Write-Host "Report ready at: $zipPath"
    Write-Host "Pull it down with the RTR 'get' command: get $zipPath"
}
catch {
    Write-Warning "Failed to compress: $($_.Exception.Message). CSV left in '$folder'."
}
