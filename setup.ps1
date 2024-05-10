# Ensure the script can run with elevated privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as an Administrator!"
    exit
}

# Function to test internet connectivity
function Test-InternetConnection {
    try {
        Test-Connection -ComputerName www.google.com -Count 1 -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Internet connection is required but not available. Please check your connection."
        return $false
    }
}

# Check for internet connectivity before proceeding
if (-not (Test-InternetConnection)) {
    exit
}

# Function to get current date and time in a specific format
function Get-DateTimeStamp {
    return (Get-Date -Format "yyyyMMddHHmmss")
}

# Profile creation or update
if (!(Test-Path -Path $PROFILE -PathType Leaf)) {
    # Set the profile path based on the PowerShell edition
    if ($PSVersionTable.PSEdition -eq "Core") {
        $profilePath = "$env:userprofile\Documents\Powershell"
    } else {
        $profilePath = "$env:userprofile\Documents\WindowsPowerShell"
    }

    # Create the profile directory if it does not exist
    if (!(Test-Path -Path $profilePath)) {
        New-Item -Path $profilePath -ItemType Directory
    }

    try {
        # Download and save the PowerShell profile from GitHub
        Invoke-RestMethod "https://github.com/NThompson480/powershell-profile/raw/main/Microsoft.PowerShell_profile.ps1" -OutFile $PROFILE
        Write-Host "The profile @ [$PROFILE] has been created. Please add any persistent components to [$profilePath\Profile.ps1]."
    }
    catch {
        Write-Error "Failed to create the profile. Error: $_"
    }
}

else {
    try {
        $dateTimeStamp = Get-DateTimeStamp
        $newProfileName = "$PROFILE.old_$dateTimeStamp"
        Rename-Item -Path $PROFILE -NewName $newProfileName
        Invoke-RestMethod "https://github.com/NThompson480/powershell-profile/raw/main/Microsoft.PowerShell_profile.ps1" -OutFile $PROFILE
        Write-Host "The profile has been updated. Old profile is renamed to [$newProfileName]. Please backup any persistent components."
    }
    catch {
        Write-Error "Failed to update the profile. Error: $_"
    }
}

# Function to check if Chocolatey is installed and install it if necessary
function Ensure-ChocolateyInstalled {
    if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey not found. Attempting to install Chocolatey..."
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Set-ExecutionPolicy Bypass -Scope Process -Force
            iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
            Write-Host "Chocolatey installed successfully."
        }
        catch {
            Write-Error "Failed to install Chocolatey. Error: $_"
        }
    }
    else {
        Write-Host "Chocolatey is already installed."
    }
}

# Ensure Chocolatey is installed before proceeding with other installations
Ensure-ChocolateyInstalled

# Function to install or update a Chocolatey package
function Install-ChocolateyPackage {
    param (
        [string]$packageName
    )
    try {
        $localPackage = choco list --local-only $packageName -r
        if ($localPackage -like "*$packageName*") {
            $localVersion = ($localPackage -split '\|')[1]
            $remotePackage = choco search $packageName -r | Where-Object { $_ -like "$packageName|*" }
            $remoteVersion = ($remotePackage -split '\|')[1]
            if ($localVersion -ne $remoteVersion) {
                Write-Host "Updating $packageName from version $localVersion to $remoteVersion."
                choco upgrade $packageName -y
            } else {
                Write-Host "$packageName is up-to-date with version $localVersion."
            }
        } else {
            Write-Host "$packageName is not installed. Installing now."
            choco install $packageName -y
        }
    }
    catch {
        Write-Error "Failed to install or update $packageName. Error: $_"
    }
}

# Install or Update Oh My Posh
Install-ChocolateyPackage -packageName "oh-my-posh"

# Install or Update zoxide
Install-ChocolateyPackage -packageName "zoxide"

# Font Installation
try {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name

    if ($fontFamilies -notcontains "CaskaydiaCove NF") {
        Write-Host "CaskaydiaCove NF font not found. Installing now..."
        $fontZipPath = ".\CascadiaCode.zip"
        if (-not (Test-Path $fontZipPath)) {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile("https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/CascadiaCode.zip", $fontZipPath)
        }

        Expand-Archive -Path $fontZipPath -DestinationPath ".\CascadiaCode" -Force
        $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
        Get-ChildItem -Path ".\CascadiaCode" -Recurse -Filter "*.ttf" | ForEach-Object {
            If (-not(Test-Path "C:\Windows\Fonts\$($_.Name)")) {        
                $destination.CopyHere($_.FullName, 0x10)
            }
        }

        Remove-Item -Path ".\CascadiaCode" -Recurse -Force
        Remove-Item -Path $fontZipPath -Force
    } else {
        Write-Host "CaskaydiaCove NF font is already installed."
    }
}
catch {
    Write-Error "Failed to download or install the Cascadia Code font. Error: $_"
}

# Function to check if a package is installed via Chocolatey
function Test-ChocolateyPackageInstalled {
    param (
        [string]$packageName
    )
    $installedPackages = choco list --local-only
    return $installedPackages -like "*$packageName*"
}

# Function to install or update the Terminal-Icons module if necessary
function Ensure-TerminalIconsInstalled {
    try {
        $installedModule = Get-Module -Name Terminal-Icons -ListAvailable

        if ($installedModule) {
            $latestModule = Find-Module -Name Terminal-Icons
            if ($installedModule.Version -lt $latestModule.Version) {
                Write-Host "Updating Terminal-Icons from version $($installedModule.Version) to $($latestModule.Version)."
                Update-Module -Name Terminal-Icons -Force
                Write-Host "Terminal-Icons updated successfully."
            } else {
                Write-Host "Terminal-Icons is up-to-date with version $($installedModule.Version)."
            }
        } else {
            Write-Host "Terminal-Icons is not installed. Installing now..."
            Install-Module -Name Terminal-Icons -Repository PSGallery -Force
            Write-Host "Terminal-Icons installed successfully."
        }
    }
    catch {
        Write-Error "Failed to manage Terminal Icons module. Error: $_"
    }
}

# Ensure Terminal Icons is installed or updated
Ensure-TerminalIconsInstalled

# Final check and message to the user
if ((Test-Path -Path $PROFILE) -and (Test-ChocolateyPackageInstalled -packageName "oh-my-posh") -and ($fontFamilies -contains "CaskaydiaCove NF") -and (Get-Module -Name Terminal-Icons -ListAvailable)) {
    Write-Host "Setup completed successfully. Please restart your PowerShell session to apply changes."
} else {
    Write-Warning "Setup completed with errors. Please check the error messages above."
}

function Ensure-PSReadLineInstalled {
    try {
        $psReadLineModule = Get-Module -Name PSReadLine -ListAvailable
        if (-not $psReadLineModule) {
            Write-Host "PSReadLine is not installed. Installing now..."
            Install-Module -Name PSReadLine -Force -Scope CurrentUser
            Write-Host "PSReadLine installed successfully."
        } else {
            Write-Host "PSReadLine is already installed."
        }
    } catch {
        Write-Error "Failed to manage PSReadLine module. Error: $_"
    }
}
Ensure-PSReadLineInstalled
