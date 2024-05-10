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
function UpdateProfile {
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
UpdateProfile

function UpdatePowerShell {
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
UpdatePowerShell

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

function EditProfile {
    vim $PROFILE.CurrentUserAllHosts
}

function ReloadProfile {
    & $profile
}

# Editor Configuration
function TestCommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

$EDITOR = if (TestCommandExists nvim) { 'nvim' }
          elseif (TestCommandExists pvim) { 'pvim' }
          elseif (TestCommandExists vim) { 'vim' }
          elseif (TestCommandExists vi) { 'vi' }
          elseif (TestCommandExists code) { 'code' }
          elseif (TestCommandExists notepad++) { 'notepad++' }
          elseif (TestCommandExists sublime_text) { 'sublime_text' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

# System Utilities
function Uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        $os = Get-WmiObject win32_operatingsystem
        $uptime = $os.ConvertToDateTime($os.lastbootuptime)
        Write-Output "System uptime since: $uptime"
    } else {
        $statistics = net statistics workstation
        $since = $statistics | Select-String "since"
        Write-Output $since
    }
}

function Sysinfo {
    Get-ComputerInfo
}

# Network Utilities
function GetPublicIP {
    (Invoke-WebRequest http://ifconfig.me/ip).Content
}

function FlushDNS {
    Clear-DnsClientCache
}

# File Management
function OpenDir {
    Start-Process explorer.exe -ArgumentList $PWD
}

function touch($file) { "" | Out-File $file -Encoding ASCII }

function ff($name) {
    $items = Get-ChildItem -Recurse -Filter "*${name}*" -ErrorAction SilentlyContinue; 
    if ($items) { $items | ForEach-Object { Write-Output $_.FullName } } 
    else { Write-Output "No files found matching *${name}*." }
}

function unzip($file) {
    $fullPath = Resolve-Path $file
    Expand-Archive -Path $fullPath -DestinationPath $PWD
    Write-Host "Extracted $file to $PWD" -ForegroundColor Green
}

function grep($regex, $dir) {
    if ($dir) {
        $items = Get-ChildItem $dir -Recurse
        foreach ($item in $items) {
            Select-String -Path $item.FullName -Pattern $regex -CaseSensitive
        }
    } else {
        $input | Select-String -Pattern $regex -CaseSensitive
    }
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    (Get-Content $file) -replace $find, $replace | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function head {
    param($Path, $n = 10)
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10)
    Get-Content $Path -Tail $n
}

function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

# Process Management
function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function k9 { Stop-Process -Name $args[0] }

# Git Utilities
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

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }
function pst { Get-Clipboard }
function CopyCsvToClipboard {
    if (-Not (Test-Path $args[0])) { Write-Error "File not found: $($args[0])"; return }
    Get-Content $args[0] | Set-Clipboard
    Write-Host "CSV content from '$($args[0])' has been copied to the clipboard." -ForegroundColor Green
}

# Navigation Shortcuts
function docs { Set-Location -Path $HOME\Documents }
function dtop { Set-Location -Path $HOME\Desktop }
function ep { vim $PROFILE }

# Listing and Formatting
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}

## Set prompt
$themeFileName = "cinnamon.omp.json"
$localConfigPath = Join-Path (Split-Path -Parent $PROFILE) $themeFileName
if (-Not (Test-Path $localConfigPath)) {
    Invoke-WebRequest "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$themeFileName" -OutFile $localConfigPath
    Write-Host "Downloaded and saved config to $localConfigPath" -ForegroundColor Green
}
oh-my-posh init pwsh --config $localConfigPath | Invoke-Expression

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

function ShowFunctions {
    Write-Host "Available custom functions with descriptions:" -ForegroundColor Cyan

    # Profile Management
    Write-Host "`nProfile Management:" -ForegroundColor Green
    Write-Output "  - UpdateProfile: Checks and updates the PowerShell profile from GitHub. Usage: UpdateProfile"
    Write-Output "  - EditProfile: Opens the current user's all hosts profile in the default editor. Usage: EditProfile"
    Write-Output "  - ReloadProfile: Reloads the PowerShell profile. Usage: ReloadProfile"
    Write-Output "  - UpdatePowerShell: Checks and updates PowerShell if a newer version is available. Usage: UpdatePowerShell"

    # System Utilities
    Write-Host "`nSystem Utilities:" -ForegroundColor Green
    Write-Output "  - Uptime: Shows system uptime since the last boot. Usage: Uptime"
    Write-Output "  - Sysinfo: Retrieves detailed system information. Usage: Sysinfo"

    # Network Utilities
    Write-Host "`nNetwork Utilities:" -ForegroundColor Green
    Write-Output "  - GetPublicIP: Retrieves the public IP address. Usage: GetPublicIP"
    Write-Output "  - FlushDNS: Clears the DNS client cache. Usage: FlushDNS"

    # File Management
    Write-Host "`nFile Management:" -ForegroundColor Green
    Write-Output "  - OpenDir: Opens the current directory in Windows Explorer. Usage: OpenDir"
    Write-Output "  - unzip: Extracts a zip file to the specified directory. Usage: unzip 'file.zip'"
    Write-Output "  - grep: Searches for patterns in files. Usage: grep 'regex' 'path'"
    Write-Output "  - df: Displays disk space usage. Usage: df"
    Write-Output "  - sed: Replaces text in a file. Usage: sed 'file' 'find' 'replace'"
    Write-Output "  - which: Finds the location of a command. Usage: which 'cmd'"
    Write-Output "  - head: Displays the first 'n' lines of a file. Usage: head 'file' 10"
    Write-Output "  - tail: Displays the last 'n' lines of a file. Usage: tail 'file' 10"
    Write-Output "  - nf: Creates a new file. Usage: nf 'filename'"
    Write-Output "  - mkcd: Creates a new directory and changes to it. Usage: mkcd 'dirname'"
    Write-Output "  - touch: Creates or updates the timestamp of a file. Usage: touch 'file'"
    Write-Output "  - ff: Finds files containing a string in their names. Usage: ff 'pattern'"

    # Process Management
    Write-Host "`nProcess Management:" -ForegroundColor Green
    Write-Output "  - pkill: Terminates processes by name. Usage: pkill 'processName'"
    Write-Output "  - pgrep: Lists all processes by name. Usage: pgrep 'processName'"
    Write-Output "  - k9: Force stops a process by name. Usage: k9 'processName'"

    # Git Utilities
    Write-Host "`nGit Utilities:" -ForegroundColor Green
    Write-Output "  - gs: Runs the 'git status' command. Usage: gs"
    Write-Output "  - ga: Stages all changes in git. Usage: ga"
    Write-Output "  - gc: Commits staged changes in git with a provided message. Usage: gc 'message'"
    Write-Output "  - gp: Pushes committed changes to a remote git repository. Usage: gp"
    Write-Output "  - g: Navigates to the GitHub directory. Usage: g"
    Write-Output "  - gcom: Stages and commits all changes in git with a specified message. Usage: gcom 'message'"
    Write-Output "  - lazyg: Stages, commits, and pushes all changes in git. Usage: lazyg 'message'"

    # Clipboard Utilities
    Write-Host "`nClipboard Utilities:" -ForegroundColor Green
    Write-Output "  - cpy: Copies text to the clipboard. Usage: cpy 'text'"
    Write-Output "  - pst: Retrieves the current content of the clipboard. Usage: pst"
    Write-Output "  - CopyCsvToClipboard: Copies contents of a CSV file to the clipboard. Usage: CopyCsvToClipboard 'file.csv'"

    # Navigation Shortcuts
    Write-Host "`nNavigation Shortcuts:" -ForegroundColor Green
    Write-Output "  - docs: Navigates to the Documents folder. Usage: docs"
    Write-Output "  - dtop: Navigates to the Desktop folder. Usage: dtop"
    Write-Output "  - ep: Opens the current PowerShell profile in the editor. Usage: ep"

    # Listing and Formatting
    Write-Host "`nListing and Formatting:" -ForegroundColor Green
    Write-Output "  - la: Lists all items in the current directory, formatted as a table. Usage: la"
    Write-Output "  - ll: Lists all items, providing detailed information. Usage: ll"
}
