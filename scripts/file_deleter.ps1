###############################################################################################################
###############################################################################################################
#### Script to delete specific files based on 5 string filters. ###############################################
###############################################################################################################
###############################################################################################################

# Define the directory path and search strings
# Prompt the user for input and assign values to search strings
$directoryPath = Read-Host "Enter the first search string" #For instance input C:\Users\ to search in all the Users folder and subfolders
$searchString1 = Read-Host "Enter the first search string"
$searchString4 = Read-Host "Enter the fourth search string"
$searchString5 = Read-Host "Enter the fifth search string"
$searchString2 = Read-Host "Enter the second search string"
$searchString3 = Read-Host "Enter the third search string"

# Search for files matching the criteria
$matchingFiles = Get-ChildItem -Path $directoryPath -File -Recurse | 
    Where-Object { $_.Name -match $searchString1 -and $_.Name -match $searchString4 -and $_.Name -match $searchString5 -and $_.Name -match $searchString2 -and $_.Name -match $searchString3 }

# Display the matching files
$matchingFiles

# Delete the matching files
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



