###############################################################################################################
###############################################################################################################
#### Script to delete specific files based on filters. ########################################################
###############################################################################################################
###############################################################################################################

param (
    [int]$NumSearchStrings,
    [string[]]$SearchStrings,
    [string]$DirectoryPath
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
    $SearchStrings | Where-Object { $fileName -match $_ }
}

# Display the matching files
if (-not $matchingFiles) {
    Write-Host "No matching files found for the given search string(s) in '$DirectoryPath'."
}
else {
    Write-Host "Found $(@($matchingFiles).Count) matching file(s):"
    $matchingFiles
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
