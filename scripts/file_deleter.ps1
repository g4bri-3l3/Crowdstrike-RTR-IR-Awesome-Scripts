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

# If search strings are not provided as arguments, prompt the user
if (-not $SearchStrings) {
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

# Search for files matching the criteria
$matchingFiles = Get-ChildItem -Path $DirectoryPath -File -Recurse | Where-Object {
    $file = $_
    $SearchStrings | ForEach-Object { $file.Name -match $_ }
}

# Display the matching files
$matchingFiles

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
$removedFilesInfo | Format-Table -AutoSize
