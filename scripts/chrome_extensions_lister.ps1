###############################################################################################################
###############################################################################################################
#### Script to extract Google Chrome Extensions. ##############################################################
###############################################################################################################
###############################################################################################################


<#
.SYNOPSIS
    Gets Chrome Extensions from a local or remote computer.
.DESCRIPTION
    This script retrieves the name, version, and description of installed Chrome extensions on local or remote computers.
    Admin rights are required to access other profiles on the local computer or any profiles on a remote computer.
    Internet access is required to lookup the extension details on the Chrome Web Store.
    You can also upload file hashes to VirusTotal for analysis (requires API key).
.PARAMETER Computername
    The name of the computer to connect to. The default is the local machine.
.PARAMETER Username
    The username to query, i.e., the userprofile (e.g., c:\users\<username>).
    If this parameter is omitted, all user profiles are searched.
.PARAMETER VirusTotalApiKey
    Your VirusTotal API key for uploading file hashes for analysis.
.EXAMPLE
    PS C:\> Get-ChromeExtension

    This command retrieves Chrome extensions from all user profiles on the local computer.
.EXAMPLE
    PS C:\> Get-ChromeExtension -Username Jsmith

    This command retrieves Chrome extensions installed under c:\users\jsmith on the local computer.
.EXAMPLE
    PS C:\> Get-ChromeExtension -Computername PC1234,PC4567

    This command retrieves Chrome extensions from all user profiles on the two specified remote computers.
.EXAMPLE
    PS C:\> Get-ChromeExtension -VirusTotalApiKey "YourApiKeyHere"

    This command uploads file hashes to VirusTotal for analysis.
.NOTES
    Version 1.0
#>
[cmdletbinding()]
PARAM(
    [parameter(Position = 0)]
    [string]$Computername = $ENV:COMPUTERNAME,

    [parameter(Position = 1)]
    [string]$Username,

    [parameter(Position = 2)]
    [string]$VirusTotalApiKey
)

BEGIN {
    function Get-ExtensionInfo {
        [cmdletbinding()]
        PARAM(
            [parameter(Position = 0)]
            [IO.DirectoryInfo]$Folder
        )

        BEGIN {
            $BuiltInExtensions = @{
                'nmmhkkegccagdldgiimedpiccmgmieda' = 'Google Wallet'
                'mhjfbmdgcfjbbpaeojofohoefgiehjai' = 'Chrome PDF Viewer'
                'pkedcjkdefgpdelpbcmbmeomcjbeemfm' = 'Chrome Cast'
            }
        }

        PROCESS {
            $ExtID = $Folder.Name

            if ($Folder.FullName -match '\\Users\\(?<username>[^\\]+)\\') {
                $Username = $Matches['username']
            } else {
                $Username = ''
            }

            $LastestExtVersionInstallFolder = Get-ChildItem -Path $Folder.Fullname | Where-Object { $_.Name -match '^[0-9\._-]+$' } | Sort-Object -Property CreationTime -Descending | Select-Object -First 1 -ExpandProperty Name

            if (Test-Path -Path "$($Folder.Fullname)\$LastestExtVersionInstallFolder\Manifest.json") {
                $Manifest = Get-Content -Path "$($Folder.Fullname)\$LastestExtVersionInstallFolder\Manifest.json" -Raw | ConvertFrom-Json
                if ($Manifest) {
                    if (-not([string]::IsNullOrEmpty($Manifest.version))) {
                        $Version = $Manifest.version
                    }
                }
            } else {
                $Version = $LastestExtVersionInstallFolder.Name
            }

            if ($BuiltInExtensions.ContainsKey($ExtID)) {
                $Title = $BuiltInExtensions[$ExtID]
                $Description = ''
            } else {
                $url = "https://chrome.google.com/webstore/detail/" + $ExtID + "?hl=en-us"

                try {
                    $WebRequest = Invoke-WebRequest -Uri $url -ErrorAction Stop

                    if ($WebRequest.StatusCode -eq 200) {
                        if (-not([string]::IsNullOrEmpty($WebRequest.ParsedHtml.title))) {
                            $ExtTitle = $WebRequest.ParsedHtml.title
                            if ($ExtTitle -match '\s-\s.*$') {
                                $Title = $ExtTitle -replace '\s-\s.*$',''
                                $extType = 'ChromeStore'
                            } else {
                                $Title = $ExtTitle
                            }
                        }

                        $Description = $webRequest.AllElements.InnerHTML | Where-Object { $_ -match '<meta name="Description" content="([^"]+)">' } | Select-Object -First 1 | ForEach-Object { $Matches[1] }
                    }
                } catch {
                    Write-Warning "Error during webstore lookup for '$ExtID' - '$_'"
                }
            }

            [PSCustomObject][Ordered]@{
                Name        = $Title
                Version     = $Version
                Description = $Description
                Username    = $Username
                ID          = $ExtID
            }
        }
    }

    $ExtensionFolderPath = 'AppData\Local\Google\Chrome\User Data\Default\Extensions'
}

PROCESS {
    Foreach ($Computer in $Computername) {
        if ($Username) {
            $Path = Join-path -path "fileSystem::\\$Computer\C$\Users\$Username" -ChildPath $ExtensionFolderPath
            $Extensions = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
        } else {
            $Path = Join-path -path "fileSystem::\\$Computer\C$\Users\*" -ChildPath $ExtensionFolderPath
            $Extensions = @()
            Get-Item -Path $Path -ErrorAction SilentlyContinue | ForEach-Object {
                $Extensions += Get-ChildItem -Path $_ -Directory -ErrorAction SilentlyContinue
            }
        }

        if ($Extensions -ne $null) {
            Foreach ($Extension in $Extensions) {
                $Output = Get-ExtensionInfo -Folder $Extension
                $Output | Add-Member -MemberType NoteProperty -Name 'Computername' -Value $Computer
                $Output
            }
        } else {
            Write-Warning "$Computer: No extensions were found"
        }
    }
}

END {
    if ($VirusTotalApiKey) {
        $hashes = @() # Store file hashes here

        # Collect file hashes for analysis (add them to the $hashes array)
        # For example: $hashes += "FileHash1", "FileHash2"

        if ($hashes.Count -gt 0) {
            Write-Host "Uploading file hashes to VirusTotal..."
            # Implement the code to upload file hashes to VirusTotal using the provided API key
        } else {
            Write-Warning "No file hashes to upload to VirusTotal."
        }
    }
}

Get-ChromeExtension
