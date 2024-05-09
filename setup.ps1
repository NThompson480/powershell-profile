# Ensure the script can run with elevated privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as an Administrator!"
    break
}

# Function to test internet connectivity
function Test-InternetConnection {
    try {
        $testConnection = Test-Connection -ComputerName www.google.com -Count 1 -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Internet connection is required but not available. Please check your connection."
        return $false
    }
}

# Check for internet connectivity before proceeding
if (-not (Test-InternetConnection)) {
    break
}

# Function to get current date and time in a specific format
function Get-DateTimeStamp {
    return (Get-Date -Format "yyyyMMddHHmmss")
}

# Profile creation or update
if (!(Test-Path -Path $PROFILE -PathType Leaf)) {
    try {
        # Detect version of PowerShell & create profile directories if they do not exist.
        $profilePath = ""
        if ($PSVersionTable.PSEdition -eq "Core") { 
            $profilePath = "$env:userprofile\Documents\Powershell"
        }
        elseif ($PSVersionTable.PSEdition -eq "Desktop") {
            $profilePath = "$env:userprofile\Documents\WindowsPowerShell"
        }

        if (!(Test-Path -Path $profilePath)) {
            New-Item -Path $profilePath -ItemType "directory"
        }

        Invoke-RestMethod https://github.com/NThompson480/powershell-profile/raw/main/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
        Write-Host "The profile @ [$PROFILE] has been created."
        Write-Host "If you want to add any persistent components, please do so at [$profilePath\Profile.ps1] as there is an updater in the installed profile which uses the hash to update the profile and will lead to loss of changes."
    }
    catch {
        Write-Error "Failed to create or update the profile. Error: $_"
    }
}
else {
    try {
        # Rename existing profile appending the current date and time
        $dateTimeStamp = Get-DateTimeStamp
        $newProfileName = "$PROFILE.old_$dateTimeStamp"
        Rename-Item -Path $PROFILE -NewName $newProfileName

        Invoke-RestMethod https://github.com/NThompson480/powershell-profile/raw/main/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
        Write-Host "The profile @ [$PROFILE] has been created and old profile renamed to [$newProfileName]."
        Write-Host "Please back up any persistent components of your old profile to [$HOME\Documents\PowerShell\Profile.ps1] as there is an updater in the installed profile which uses the hash to update the profile and will lead to loss of changes."
    }
    catch {
        Write-Error "Failed to backup and update the profile. Error: $_"
    }
}

# Function to check if Chocolatey is installed
function Ensure-ChocolateyInstalled {
    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if ($null -eq $chocoPath) {
        Write-Host "Chocolatey not found. Attempting to install Chocolatey..."
        try {
            # Set higher security protocol, necessary for accessing Chocolatey on HTTPS
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            
            # Download and install Chocolatey
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

# Call the function to ensure Chocolatey is installed before proceeding with other installations
Ensure-ChocolateyInstalled

# Improved function to install or update a Chocolatey package
function Install-ChocolateyPackage {
    param (
        [string]$packageName
    )
    try {
        # Check if the package is already installed
        $localPackage = choco list --local-only $packageName -r

        if ($localPackage) {
            # Check if the package is up-to-date
            $localVersion = $localPackage -split '\|' | Select-Object -Index 1
            $remotePackage = choco search $packageName -r | Where-Object { $_ -like "$packageName|*" }
            $remoteVersion = $remotePackage -split '\|' | Select-Object -Index 1

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

# Oh My Posh Install or Update
Install-ChocolateyPackage -packageName "oh-my-posh"

# zoxide Install or Update
Install-ChocolateyPackage -packageName "zoxide"

# Font Install
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
        # Check if Terminal-Icons is installed
        $installedModule = Get-Module -Name Terminal-Icons -ListAvailable

        if ($installedModule) {
            # Check for updates
            $latestModule = Find-Module -Name Terminal-Icons
            if ($installedModule.Version -lt $latestModule.Version) {
                Write-Host "Updating Terminal-Icons from version $($installedModule.Version) to $($latestModule.Version)."
                Update-Module -Name Terminal-Icons -Force
                Write-Host "Terminal-Icons updated successfully."
            } else {
                Write-Host "Terminal-Icons is up-to-date with version $($installedModule.Version)."
            }
        } else {
            # Install the module if not installed
            Write-Host "Terminal-Icons is not installed. Installing now..."
            Install-Module -Name Terminal-Icons -Repository PSGallery -Force
            Write-Host "Terminal-Icons installed successfully."
        }
    }
    catch {
        Write-Error "Failed to manage Terminal Icons module. Error: $_"
    }
}

# Call the function to ensure Terminal Icons is installed or updated
Ensure-TerminalIconsInstalled

# Final check and message to the user
if ((Test-Path -Path $PROFILE) -and (Test-ChocolateyPackageInstalled -packageName "oh-my-posh") -and ($fontFamilies -contains "CaskaydiaCove NF")) {
    Write-Host "Setup completed successfully. Please restart your PowerShell session to apply changes."
} else {
    Write-Warning "Setup completed with errors. Please check the error messages above."
}
