###############################################################################################################
###############################################################################################################
#### Script to delete specific files based on filters. ########################################################
###############################################################################################################
###############################################################################################################

param (
    [int]$NumSearchStrings,
    [string[]]$SearchStrings,
    [string]$DirectoryPath,
    # Search strings are treated as literal substrings by default. Pass
    # -UseRegex to opt into the previous behavior (each string is a regex
    # pattern) - without this, a string like "report.docx" would also match
    # "reportXdocx" etc., since "." is a regex wildcard.
    [switch]$UseRegex,
    # Skip the confirmation prompt before deleting (e.g. for non-interactive
    # automation). Default requires typing YES after the match list is shown.
    [switch]$Force
)

# If search strings are not provided as arguments, prompt the user.
# If -NumSearchStrings was also not provided, it defaults to 0 - ask for it
# here instead of silently looping zero times (which previously produced an
# empty $SearchStrings and matched nothing at all).
if (-not $SearchStrings) {
    if (-not $NumSearchStrings -or $NumSearchStrings -le 0) {
        $NumSearchStrings = [int](Read-Host "How many search strings do you want to enter?")
    }
    $SearchStrings = @()
    for ($i = 1; $i -le $NumSearchStrings; $i++) {
        $searchString = Read-Host "Enter search string $i"
        $SearchStrings += $searchString
    }
}

# If directory path is not provided as an argument, prompt the user
if (-not $DirectoryPath) {
    $DirectoryPath = Read-Host "Enter the directory path"
}

# Search for files matching the criteria.
$matchingFiles = Get-ChildItem -Path $DirectoryPath -File -Recurse | Where-Object {
    $fileName = $_.Name
    $SearchStrings | Where-Object {
        if ($UseRegex) { $fileName -match $_ } else { $fileName -match [regex]::Escape($_) }
    }
}

# Display the matching files
if (-not $matchingFiles) {
    Write-Host "No matching files found for the given search string(s) in '$DirectoryPath'."
}
else {
    Write-Host "Found $(@($matchingFiles).Count) matching file(s):"
    $matchingFiles
}

# Require explicit confirmation before permanently deleting anything, unless
# -Force was passed (e.g. for scripted/non-interactive runs).
if ($matchingFiles -and -not $Force) {
    $confirmation = Read-Host "Type YES to permanently delete the $(@($matchingFiles).Count) file(s) listed above"
    if ($confirmation -ne 'YES') {
        Write-Host "Aborted - no files were deleted."
        return
    }
}

# Initialize an array to store information about removed files
$removedFilesInfo = @()

# Delete the matching files and log information
foreach ($file in $matchingFiles) {
    $fileInfo = [PSCustomObject]@{
        FileName = $file.Name
        FullPath = $file.FullName
        RemovalTime = Get-Date
    }

    # Log information about the removed file
    $removedFilesInfo += $fileInfo

    # Remove the file
    Remove-Item -Path $file.FullName -Force
}

# Output information about removed files
if (-not $removedFilesInfo) {
    Write-Host "No files were deleted."
}
else {
    Write-Host "Deleted $($removedFilesInfo.Count) file(s):"
    $removedFilesInfo | Format-Table -AutoSize
}
