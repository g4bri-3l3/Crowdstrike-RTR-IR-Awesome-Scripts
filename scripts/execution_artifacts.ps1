###############################################################################################################
###############################################################################################################
#### Script to collect execution artifacts (Prefetch, Amcache, recent LNK) for offline analysis. ##############
###############################################################################################################
###############################################################################################################

<#
.SYNOPSIS
    Copies Prefetch files, Amcache.hve and per-user recent LNK files into a zip for offline analysis.
.DESCRIPTION
    Meant to be parsed offline (e.g. with Eric Zimmerman's PECmd, AmcacheParser and LECmd).
    Amcache.hve is locked while Windows is running, so a plain copy is tried first and
    "esentutl /y /vss" (volume shadow copy) is used as a fallback. Needs admin/SYSTEM.
.PARAMETER OutputPath
    Base folder for the output (default C:\Windows\Temp\ir_exec).
#>

[CmdletBinding()]
Param (
    [string]$OutputPath = "C:\Windows\Temp\ir_exec"
)

$folder = Join-Path $OutputPath (Get-Date -Format "yyyyMMdd_HHmmss")
New-Item -Path $folder -ItemType Directory -Force | Out-Null

# Prefetch
$prefetch = "C:\Windows\Prefetch"
if (Test-Path $prefetch) {
    $pfDest = Join-Path $folder "Prefetch"
    New-Item -Path $pfDest -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$prefetch\*.pf" -Destination $pfDest -ErrorAction SilentlyContinue
    Write-Host "Copied $((Get-ChildItem $pfDest -File).Count) prefetch files"
}
else {
    Write-Warning "Prefetch folder not found (disabled, or a server SKU)."
}

# Amcache.hve (+ transaction logs)
$amcacheDest = Join-Path $folder "Amcache"
New-Item -Path $amcacheDest -ItemType Directory -Force | Out-Null
$amcache = "C:\Windows\appcompat\Programs\Amcache.hve"
try {
    Copy-Item -Path $amcache -Destination $amcacheDest -ErrorAction Stop
    Write-Host "Copied Amcache.hve"
}
catch {
    Write-Warning "Plain copy of Amcache.hve failed ($($_.Exception.Message)). Trying esentutl /vss."
    esentutl.exe /y $amcache /vss /d (Join-Path $amcacheDest "Amcache.hve") | Out-Null
    if (Test-Path (Join-Path $amcacheDest "Amcache.hve")) { Write-Host "Copied Amcache.hve via VSS" }
    else { Write-Warning "Could not collect Amcache.hve." }
}
Copy-Item -Path "C:\Windows\appcompat\Programs\Amcache.hve.LOG*" -Destination $amcacheDest -ErrorAction SilentlyContinue

# Recent LNK files for every user profile
Get-ChildItem "C:\Users" -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $recent = Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Recent"
    if (Test-Path $recent) {
        $dest = Join-Path $folder "Recent\$($_.Name)"
        New-Item -Path $dest -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$recent\*.lnk" -Destination $dest -ErrorAction SilentlyContinue
        Write-Host "Copied $((Get-ChildItem $dest -File).Count) LNK files for $($_.Name)"
    }
}

$zipPath = "$folder.zip"
try {
    Compress-Archive -Path "$folder\*" -DestinationPath $zipPath -Force -ErrorAction Stop
    if (Test-Path $zipPath) {
        Remove-Item -Path $folder -Recurse -Force
        Write-Host "Artifacts ready at: $zipPath"
        Write-Host "Pull it down with the RTR 'get' command: get $zipPath"
    }
}
catch {
    Write-Warning "Failed to compress: $($_.Exception.Message). Files left in '$folder'."
}
