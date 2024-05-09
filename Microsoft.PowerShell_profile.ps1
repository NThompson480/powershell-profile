### PowerShell Profile Refactor
### Version 1.03 - Refactored

# Determine PowerShell version
$PSVersion = $PSVersionTable.PSVersion.Major

# Test connection with conditional TimeoutSeconds parameter
if ($PSVersion -ge 6) {
    $canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1
} else {
    $canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet
}

# Import Modules and External Profiles
# Ensure Terminal-Icons module is installed before importing
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module -Name Terminal-Icons
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# Check for Profile Updates
function Update-Profile {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping profile update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    Write-Host "Initiating profile update check..." -ForegroundColor Cyan
    $tempFile = "$env:temp/Microsoft.PowerShell_profile.ps1"

    try {
        $url = "https://raw.githubusercontent.com/NThompson480/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        Write-Host "Downloading the latest profile from GitHub..." -ForegroundColor Cyan
        $oldhash = Get-FileHash $PROFILE -ErrorAction SilentlyContinue

        if ($oldhash) {
            Write-Host "Current profile hash: $($oldhash.Hash)" -ForegroundColor Gray
        } else {
            Write-Host "No existing profile hash found (possibly new installation)." -ForegroundColor Yellow
        }

        Invoke-RestMethod $url -OutFile $tempFile
        $newhash = Get-FileHash $tempFile
        Write-Host "Latest profile hash: $($newhash.Hash)" -ForegroundColor Gray

        if ($newhash.Hash -ne $oldhash.Hash) {
            Write-Host "A new version of the profile has been detected. Updating profile..." -ForegroundColor Yellow
            Copy-Item -Path $tempFile -Destination $PROFILE -Force
            Write-Host "Profile has been updated successfully. Please restart your shell to reflect changes." -ForegroundColor Magenta
        } else {
            Write-Host "Your PowerShell profile is already up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to check or update profile. Error: $_"
    } finally {
        if (Test-Path $tempFile) {
            Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            Write-Host "Cleanup complete." -ForegroundColor Green
        } else {
            Write-Host "No temporary files to clean up." -ForegroundColor Green
        }
    }
}
Update-Profile

function Update-PowerShell {
    # Only proceed if PowerShell version is 7 or higher
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        # Write-Host "This function is intended for PowerShell Core 7 or newer." -ForegroundColor Yellow
        return
    }

    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping PowerShell update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')

        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            Write-Host "Downloading the latest PowerShell..." -ForegroundColor Yellow
            $asset = $latestReleaseInfo.assets | Where-Object { $_.name -like "*win-x64.msi" } # Assuming Windows 64-bit MSI installer
            $downloadUrl = $asset.browser_download_url
            $localPath = "$env:TEMP\PowerShell-latest.msi"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $localPath

            Write-Host "Installing the latest PowerShell..." -ForegroundColor Yellow
            Start-Process msiexec.exe -ArgumentList "/i `"$localPath`" /quiet /norestart" -Wait

            Write-Host "PowerShell has been updated. Please restart your shell to reflect changes." -ForegroundColor Magenta
        } else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}
Update-PowerShell

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Utility Functions
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Editor Configuration
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
          elseif (Test-CommandExists pvim) { 'pvim' }
          elseif (Test-CommandExists vim) { 'vim' }
          elseif (Test-CommandExists vi) { 'vi' }
          elseif (Test-CommandExists code) { 'code' }
          elseif (Test-CommandExists notepad++) { 'notepad++' }
          elseif (Test-CommandExists sublime_text) { 'sublime_text' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

function Edit-Profile {
    vim $PROFILE.CurrentUserAllHosts
}
function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.directory)\$($_)"
    }
}

# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# System Utilities
function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name='LastBootUpTime'; Expression={$_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
    } else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}

function reload-profile {
    & $profile
}

function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}

function tail {
  param($Path, $n = 10)
  Get-Content $Path -Tail $n
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

### Quality of Life Aliases

# Navigation Shortcuts
function docs { Set-Location -Path $HOME\Documents }

function dtop { Set-Location -Path $HOME\Desktop }

# Quick Access to Editing the Profile
function ep { vim $PROFILE }

# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# Git Shortcuts
function gs { git status }

function ga { git add . }

function gc { param($m) git commit -m "$m" }

function gp { git push }

function g { z Github }

function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns { Clear-DnsClientCache }

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}

## Final Line to set prompt
oh-my-posh init pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cinnamon.omp.json | Invoke-Expression

# Check for the zoxide command, install with Chocolatey if not found
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
} else {
    Write-Host "zoxide command not found. Attempting to install via Chocolatey..."
    try {
        choco install zoxide -y
        Write-Host "zoxide installed successfully. Initializing..."
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    } catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}

function Show-Functions {
    Write-Host "Available custom functions with descriptions:" -ForegroundColor Cyan

    # Profile Management
    Write-Host "`nProfile Management:" -ForegroundColor Green
    Write-Output "  - Update-Profile: Checks and updates the PowerShell profile from GitHub if a new version is detected."
    Write-Output "  - Edit-Profile: Opens the current user's all hosts profile in the default editor."
    Write-Output "  - reload-profile: Reloads the PowerShell profile."
    Write-Output "  - Update-PowerShell: Checks for the latest version of PowerShell and updates it if a newer version is available."

    # System Utilities
    Write-Host "`nSystem Utilities:" -ForegroundColor Green
    Write-Output "  - uptime: Shows the system uptime."
    Write-Output "  - sysinfo: Retrieves detailed system information."

    # Network Utilities
    Write-Host "`nNetwork Utilities:" -ForegroundColor Green
    Write-Output "  - Get-PubIP: Retrieves the public IP address of the current connection."
    Write-Output "  - flushdns: Clears the DNS client cache."

    # File Management
    Write-Host "`nFile Management:" -ForegroundColor Green
    Write-Output "  - unzip: Extracts a zip file to the current directory."
    Write-Output "  - grep: Searches for patterns matching a specified regex in files or standard input."
    Write-Output "  - df: Displays disk space usage for all mounted drives."
    Write-Output "  - sed: Replaces text in a specified file."
    Write-Output "  - which: Finds the location of a command."
    Write-Output "  - head: Displays the first 'n' lines of a file."
    Write-Output "  - tail: Displays the last 'n' lines of a file."
    Write-Output "  - nf: Creates a new file in the current directory."
    Write-Output "  - mkcd: Creates a new directory and changes to it."

    # Process Management
    Write-Host "`nProcess Management:" -ForegroundColor Green
    Write-Output "  - pkill: Terminates processes with the specified name."
    Write-Output "  - pgrep: Lists all processes with the specified name."
    Write-Output "  - k9: Force stops a process by name."

    # Git Utilities
    Write-Host "`nGit Utilities:" -ForegroundColor Green
    Write-Output "  - gs: Runs the 'git status' command."
    Write-Output "  - ga: Stages all changes in git."
    Write-Output "  - gc: Commits staged changes in git with a provided message."
    Write-Output "  - gp: Pushes committed changes to the remote git repository."
    Write-Output "  - g: Navigates to the GitHub directory."
    Write-Output "  - gcom: Stages and commits all changes in git with a specified message."
    Write-Output "  - lazyg: Stages, commits, and pushes all changes in git with a specified message."

    # Clipboard Utilities
    Write-Host "`nClipboard Utilities:" -ForegroundColor Green
    Write-Output "  - cpy: Copies the specified text to the clipboard."
    Write-Output "  - pst: Retrieves the current content of the clipboard."

    # Navigation Shortcuts
    Write-Host "`nNavigation Shortcuts:" -ForegroundColor Green
    Write-Output "  - docs: Navigates to the Documents folder."
    Write-Output "  - dtop: Navigates to the Desktop folder."
    Write-Output "  - ep: Opens the current PowerShell profile in the default editor."

    # Listing and Formatting
    Write-Host "`nListing and Formatting:" -ForegroundColor Green
    Write-Output "  - la: Lists all items in the current directory including hidden ones, formatted as a table."
    Write-Output "  - ll: Lists all items including hidden ones, providing detailed information."
}
