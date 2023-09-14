###############################################################################################################
###############################################################################################################
#### Script to delete specific files based on filters. ########################################################
###############################################################################################################
###############################################################################################################

# Prompt the user for the number of search strings
$numSearchStrings = Read-Host "Enter the number of search strings"

# Initialize an array to store search strings
$searchStrings = @()

# Prompt the user for search strings based on the specified number
for ($i = 1; $i -le $numSearchStrings; $i++) {
    $searchString = Read-Host "Enter search string $i"
    $searchStrings += $searchString
}

# Prompt the user for the directory path
$directoryPath = Read-Host "Enter the directory path"

# Search for files matching the criteria
$matchingFiles = Get-ChildItem -Path $directoryPath -File -Recurse | Where-Object {
    $file = $_
    $searchStrings | ForEach-Object { $file.Name -match $_ }
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
