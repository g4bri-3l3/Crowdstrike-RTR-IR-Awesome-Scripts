###############################################################################################################
###############################################################################################################
#### A simple script to create a local admin user. Replace the password ASAP!!! ###############################
###############################################################################################################
###############################################################################################################

param (
    [Parameter(Mandatory=$true, HelpMessage="Enter the username")]
    [string]$Username,

    [Parameter(Mandatory=$true, HelpMessage="Enter the password")]
    [string]$Password,

    [Parameter(Mandatory=$true, HelpMessage="Enter the full name")]
    [string]$FullName,

    [Parameter(Mandatory=$true, HelpMessage="Enter the user description")]
    [string]$Description
)

# Prompt the user for a secure password
$securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

# Creating the user
New-LocalUser -Name $Username -Password $securePassword -FullName $FullName -Description $Description

# Add the user to the Administrators group
Add-LocalGroupMember -Group Administrators -Member $Username

