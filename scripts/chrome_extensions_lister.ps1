###############################################################################################################
###############################################################################################################
#### Script to extract Google Chrome Extensions. ##############################################################
###############################################################################################################
###############################################################################################################

function Get-ChromeExtension {
    <#
    .SYNOPSIS
        Gets Chrome Extensions from a local or remote computer.
    .DESCRIPTION
        This script retrieves the name, version, and description of installed Chrome extensions on local or remote computers.
        Admin rights are required to access other profiles on the local computer or any profiles on a remote computer.
        Internet access is required to lookup the extension details on the Chrome Web Store.
        NOTE: -VirusTotalApiKey is currently a documented placeholder, not a working feature - see the END block.
    .PARAMETER Computername
        The name of the computer to connect to. The default is the local machine.
    .PARAMETER Username
        The username to query, i.e., the userprofile (e.g., c:\users\<username>).
        If this parameter is omitted, all user profiles are searched.
    .PARAMETER VirusTotalApiKey
        Your VirusTotal API key. NOT YET IMPLEMENTED - see the END block for details.
    .EXAMPLE
        PS C:\> Get-ChromeExtension

        This command retrieves Chrome extensions from all user profiles on the local computer.
    .EXAMPLE
        PS C:\> Get-ChromeExtension -Username Jsmith

        This command retrieves Chrome extensions installed under c:\users\jsmith on the local computer.
    .EXAMPLE
        PS C:\> Get-ChromeExtension -Computername PC1234,PC4567

        This command retrieves Chrome extensions from all user profiles on the two specified remote computers.
    .NOTES
        Version 1.2 - the whole script body is now wrapped in an actual
        "function Get-ChromeExtension { ... }" definition. Previously, Param/
        Begin/Process/End sat directly at script scope with no such function
        ever defined, so the final call to "Get-ChromeExtension" failed with
        CommandNotFoundException - the name existed only in the docs/examples,
        never as a real defined command.
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
                    # $LastestExtVersionInstallFolder is already a plain string
                    # (Select-Object -ExpandProperty Name above flattens it).
                    # Calling .Name on it again returns $null, since strings
                    # don't have a .Name property.
                    $Version = $LastestExtVersionInstallFolder
                }

                if ($BuiltInExtensions.ContainsKey($ExtID)) {
                    $Title = $BuiltInExtensions[$ExtID]
                    $Description = ''
                } else {
                    $url = "https://chrome.google.com/webstore/detail/" + $ExtID + "?hl=en-us"

                    try {
                        $WebRequest = Invoke-WebRequest -Uri $url -ErrorAction Stop -UseBasicParsing

                        if ($WebRequest.StatusCode -eq 200) {
                            # Regex-based title/description extraction instead of
                            # .ParsedHtml (IE/MSHTML-dependent, often missing or
                            # broken on modern Windows and unavailable in
                            # PowerShell 7+). -UseBasicParsing avoids the same
                            # dependency at the Invoke-WebRequest level too.
                            if ($WebRequest.Content -match '<title>(.*?)</title>') {
                                $ExtTitle = [System.Net.WebUtility]::HtmlDecode($Matches[1])
                                if ($ExtTitle -match '\s-\s.*$') {
                                    $Title = $ExtTitle -replace '\s-\s.*$', ''
                                } else {
                                    $Title = $ExtTitle
                                }
                            }

                            if ($WebRequest.Content -match '<meta name="Description" content="([^"]+)"') {
                                $Description = [System.Net.WebUtility]::HtmlDecode($Matches[1])
                            } else {
                                $Description = ''
                            }
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

            if ($Extensions) {
                Foreach ($Extension in $Extensions) {
                    $Output = Get-ExtensionInfo -Folder $Extension
                    $Output | Add-Member -MemberType NoteProperty -Name 'Computername' -Value $Computer
                    $Output
                }
            } else {
                Write-Warning "${Computer}: No extensions were found"
            }
        }
    }

    END {
        if ($VirusTotalApiKey) {
            # NOT YET IMPLEMENTED. There's no single natural "file hash" for a
            # Chrome extension the way there is for a binary - an extension is
            # a folder of many files (manifest.json plus JS/assets), so a real
            # implementation needs a deliberate choice of what to hash (e.g.
            # the packed .crx if you download one, or a hash of manifest.json
            # as a weaker proxy) before it can call the VirusTotal API. Rather
            # than leave a silent no-op stub, this warns loudly so nobody
            # assumes VT checking is happening when it isn't.
            Write-Warning "VirusTotalApiKey was provided, but hash lookup is not implemented in this script yet - no VirusTotal check was performed."
        }
    }
}

# Actually invoke the function - this is a plain top-level statement (not
# inside a named block), which is valid after the function definition closes.
Get-ChromeExtension
