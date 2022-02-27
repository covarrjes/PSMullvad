# PSMullvad
PowerShell module to control Mullvad VPN logic. 
https://mullvad.net/en/

## Get-LatestMullvadVersion
Checks the upstream version and keeps the current up to date. 

## Invoke-MullvadUpdate 
Downloads and installs the latest Mullvad update as needed. 

## Set-MullvadAccount
Sets the account number (token) to the settings.

## Get-MullvadAccount 
Verifies that an account is set. 

## Assert-MullvadAccount
Controls the Get-MullvadAccount and Set-MullvadAccount as needed. 

## Get-MullvadStatus
Returns the VPN status and if a connection is required at runtime, it will force different logic to ensure connectivity. 

## Connect-Mullvad
Initiates Mullvad VPN connection.

## Restart-Mullvad 
Reconnects / reattempts a VPN connection.

## Disconnect-Mullvad
Disconnects the Mullvad VPN connection.

## Reset-Mullvad
Completes a factory reset of the Mullvad configurations. 
