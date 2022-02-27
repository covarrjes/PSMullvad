function Get-LatestMullvadVersion {
    <#
    .SYNOPSIS
    Checks if the latest version of Mullvad is installed. If not, an installation is invoked.
    
    .DESCRIPTION
    Using the array returned by mullvad version, it compares the latest and current installed version.
    It invokes a download if needed using the installation link and retries 3 times if any failures are
    found. If an update is successful or the latest version is already installed, it returns a $true val.

    .EXAMPLE
    mullvad.exe version
    
    .NOTES
    There doesn't seem to be a need to compare which value is more recent as the version array will 
    always indicate which is the most recent. 
    #>#
    $VersionInfo = mullvad.exe version
    $Latest = $false
    $CurrentVersion = $VersionInfo[0].Replace('Current version: ', '')
    $LatestVersion = $VersionInfo[3].trim().Replace('Latest stable version: ', '')
    if (-not($CurrentVersion -eq $LatestVersion)) {
        Write-Warning "Mullvad: Upstream version found: $LatestVersion"
        $InstallParams = @{
            Destination     = "D:\downloads"
            Source          = "https://mullvad.net/download/app/exe/latest/"
        }
        $Attempt = Invoke-MullvadUpdate @InstallParams
        $AttemptCount = 1
        while (-not($Attempt) -and ($AttemptCount -lt 4)) {
            Write-Warning "Mullvad: Retrying attempt #$AttemptCount"
            $Attempt = Invoke-MullvadUpdate @InstallParams
        }
        if ($Attempt) {
            Write-Warning "Mullvad: Update invoked succesfully"
            $Latest = $true
        } else {
            Write-Warning "Mullvad: Update invoke failed"
        }
        #Download and install update
    } else {
        Write-Warning "Mullvad: $CurrentVersion is the latest version - No action"
        $Latest = $true
    }
    $Latest
}

function Invoke-MullvadUpdate {
    <#
    .SYNOPSIS
    Installs the latest version of mullvad from a source website.
    
    .DESCRIPTION
    It downloads an exe and silently installs it without need to go through the installation menu. 
    
    .PARAMETER Destination
    The download location for the .exe installer. 
    
    .PARAMETER Source
    The source https link that will be serving the webrequest.
    
    .NOTES
    The installation will be successful even if the mullvad application is running. It will keep 
    the profile settings unless they are removed. 
    #>
    [CmdletBinding()]
    param (
        [string]
        $Destination,

        [string]
        $Source
    )
    $FilePath = "$Destination\MullvadInstaller.exe"
    $Installed = $false
    $Download = Invoke-Webrequest -Uri $Source -OutFile $FilePath
    Write-Warning "Mullvad: Downloading Mullvad update"
    $InstallationArgs = @('/S', '/v', '/qn')
    Start-Sleep -s 5 
    if (Test-Path -Path $FilePath) {
        Start-Process -FilePath $FilePath -Wait -ArgumentList $InstallationArgs -PassThru
        Write-Warning "Mullvad: Update installed"
        $Installed = $true
    } else {
        Write-Warning "Mullvad: Installer not found in $Destination"
        Write-Warning "Mullvad: Download request info: $Download"
    }
    $Installed 
}

function Set-MullvadAccount {
    <#
    .SYNOPSIS
    Grabs the account token and sets it in the mullvad configs.
    
    .DESCRIPTION
    Using a source text file that only stores the account token (in plaintext) it sets the
    account token. 
    
    .PARAMETER AccountFile
    Location of plaintext file that contains the account token.
    
    .EXAMPLE
    $AccountToken = '<account-number-here>
    $AccountFile = D:\mullvad\account.txt
    Set-Content -Path $AccountFile -Value $AccountToken
    Set-MullvadAccount -AccountFile $AccountFile
    
    .NOTES
    This is a handler for a unique case that the mullvad account is unset / fails. 
    I don't expect it to happen. I need to improve storing the account token vs 
    having it in plaintext. 
    #>
    [CmdletBinding()]
    param (
        [string]
        $AccountFile
    )
    if (Test-Path -Path $AccountFile) {
        $AccountToken = Get-Content -Path $AccountFile -Raw
        mullvad.exe account set $AccountToken
        Write-Warning "Mullvad: Account token set. Unsure of why this was activated..."
        $AccountSet = $true
    } else {
        Write-Warning "Mullvad: No account token found at: $AccountFile"
        $AccountSet = $false
    }
    $AccountSet
}

function Get-MullvadAccount {
    <#
    .SYNOPSIS
    Checks if a Mullvad account is set
    
    .DESCRIPTION
    Returns a t/f condition on a mullvad.exe account get basis 
    
    .EXAMPLE
    Get-MullvadAccount
    #>
    $Account = mullvad.exe account get
    if ($Account -eq "No account configured") {
        Write-Warning "Mullvad: No account token configured in the settings"
        $AccountFound = $false
    } else {
        Write-Warning "Mullvad: Account info configured properly"
        $AccountFound = $true
    }
    $AccountFound
}

function Assert-MullvadAccount {
    <#
    .SYNOPSIS
    Verifies mullvad account set. If not, sets an account. 
    
    .NOTES
    This typically shouldn't be false. 
    #>
    $AccountFile = 'D:\mullvad-account\account.txt'
    $AccountFound = Get-MullvadAccount
    if (-not($AccountFound)) {
        $AccountAsserted = Set-MullvadAccount -AccountFile $AccountFile
    } else {
        Write-Warning "Mullvad: Mullvad account asserted"
        $AccountAsserted = $true
    }
    $AccountAsserted
}

function Get-MullvadStatus {
    <#
    .SYNOPSIS
    Returns the status of the mullvad connection.
    
    .DESCRIPTION
    Can be connected, disconnected, connecting, tunnel blocked, and unknown. 
    
    .PARAMETER Required
    A boolean value to determine if the status SHOULD be connected. If not, it just simply returns
    the status. If it is required, it will wait until it is connected if it is in a connecting state.
    If it is in a failed state for too many attempts, it will try to disconnect, validate account, etc.
    
    .EXAMPLE
    Get-MullvadStatus -Required $true 

    .EXAMPLE
    Get-MullvadStatus -Required $false
    
    .NOTES
    Failures can also occur if mullvad itself is experiencing connectivity issues. I currently 
    don't know what logic to look out for but it is on a todo.
    #>
    [CmdletBinding()]
    param (
        [boolean]
        $Required # is the VPN supposed to be connected or are we just ensuring that 
        # it is disconnected? 
    )
    # at some point - dissect the address to get the port for port forwarding? 
    $Connected = $false
    $AttemptCount = 1
    $Status = mullvad.exe status

    if (-not($Required)) {
        if ($Status -match "Tunnel status: Disconnected") {
            $Connected = $false
            Write-Warning "$Status"
        } elseif ($Status -match "Tunnel status: Connected") {
            $Connected = $true
            Write-Warning "$Status"
        } else {
            Write-Warning "$Status"
            Disconnect-Mullvad
            $Connected = $False
        }
    }

    while (($Connected -eq $false) -and ($AttemptCount -lt 25) -and $Required) {
        if ($Status -match "Tunnel status: Connected") {
            $Connected = $true
            Write-Warning "Mullvad: Status: Connected"
        } elseif ($Status -match "Tunnel status: Connecting") {
            Write-Warning "Mullvad: Status: Connecting"
        } elseif ($Status -match "Tunnel status: Blocked") {
            if ($AttemptCount -gt 3) {
                Write-Warning "Mullvad: CRIT: Attempted to connect 3 times $Status"
                Write-Warning "Mullvad: Asserting account for potential resolution"
                Disconnect-Mullvad
                $AccountAsserted = Assert-MullvadAccount
                if ($AccountAsserted) {
                    Connect-Mullvad
                    Start-Sleep -s 5
                } else {
                    Write-Warning "Mullvad: CRIT: Account failing"
                }
            }
        } elseif ($Status -match "Tunnel Status: Disconnected") {
            Connect-Mullvad
            Write-Warning "Mullvad: Status: Disconnected, reconnecting now"
            Start-Sleep -s 5
        } else {
            Write-Warning "Mullvad: CRIT: Unknown status $Status"
            Write-Warning "Mullvad: Check if Mullvad is experiencing outages"
            Disconnect-Mullvad 
            Restart-Mullvad
            Start-Sleep -s 60
        }
        $AttemptCount += 1
        $Status = mullvad.exe status
        Start-Sleep -s 2
    }

    if ($AttemptCount -ge 100) {
        # Factory reset and reset account
        # At this time, it shouldn't be hit. 
        Reset-Mullvad
    }
    $Connected
}

function Connect-Mullvad {
    mullvad.exe connect
}

function Restart-Mullvad {
    mullvad.exe reconnect
}

function Disconnect-Mullvad {
    mullvad.exe disconnect
}

function Reset-Mullvad {
    mullvad.exe factory-reset
}