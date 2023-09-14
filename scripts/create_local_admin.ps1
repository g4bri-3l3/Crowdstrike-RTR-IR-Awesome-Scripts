###############################################################################################################
###############################################################################################################
#### A simple script to create a local admin user. Replace the password ASAP!!! ###############################
###############################################################################################################
###############################################################################################################

# Username and Password
$username = "tempadmin"

# Prompt the user for a secure password
$credential = Get-Credential -Message "Enter the password for user $username"

# Extract the password from the credential
$password = $credential.Password

# Creating the user
New-LocalUser -Name "$username" -Password $password -FullName "$username" -Description "Utente admin temp"

# Add the user to the Administrators group
Add-LocalGroupMember -Group Administrators -Member admintemp
