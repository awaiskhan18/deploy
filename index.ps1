# Define project path (you could make this a parameter for flexibility)
$projectPath = Get-Location

# --- Functions ---

# Check if a command exists
function Test-Command {
    param ([string]$CommandName)
    return (Get-Command $CommandName -ErrorAction SilentlyContinue) -ne $null
}

# Get PowerShellGet version
function Get-PowerShellGetVersion {
    $module = Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1
    if ($module) {
        return $module.Version
    } else {
        return [version]"0.0"
    }
}

# Check if PHP Manager module is installed
function Check-PHPManager {
    return (Get-Module -ListAvailable -Name PhpManager) -ne $null
}

# Install PHP Manager module using appropriate command based on PowerShellGet version
function Install-PHPManager {
    $psGetVersion = Get-PowerShellGetVersion
    if ($psGetVersion -ge [version]"3.0.0") {
        Write-Output "Installing PHP Manager module using Install-PSResource..."
        Install-PSResource -Name PhpManager -Force -Scope CurrentUser
    } else {
        Write-Output "Installing PHP Manager module using Install-Module..."
        Install-Module -Name PhpManager -Force -Scope CurrentUser
    }
}

# Check Composer
function Check-Composer {
    return (Test-Command "composer")
}

# Install Composer
function Install-Composer {
    Write-Output "Composer not found. Installing Composer..."
    Invoke-WebRequest -Uri https://getcomposer.org/installer -OutFile composer-setup.php
    php composer-setup.php --install-dir=C:\composer --filename=composer
    Remove-Item -Path composer-setup.php
    Update-EnvironmentPath -pathToAdd "C:\composer"  # Update PATH for Composer
}

# Prompt the user to select PHP options and version
function Select-PHP {
    # Prompt user to enter PHP version
    $phpVersion = Read-Host "Enter the PHP version (e.g., 7.2, 8.0, etc.)"

    # Prompt user to select thread type
    $threadTypes = @("safe", "non-safe")
    Write-Output "Select thread type:"
    for ($i = 0; $i -lt $threadTypes.Length; $i++) {
        Write-Output "[$($i + 1)]  $($threadTypes[$i])"
    }
    do {
        $selection = Read-Host "Enter the number corresponding to your choice"
        $selectedThreadIndex = $selection - 1  # Convert to 0-based index
        if ($selectedThreadIndex -lt 0 -or $selectedThreadIndex -ge $threadTypes.Length) {
            Write-Output "Invalid choice. Please enter a number between 1 and $($threadTypes.Length)."
        }
    } until ($selectedThreadIndex -ge 0 -and $selectedThreadIndex -lt $threadTypes.Length)
    $threadSafe = if ($threadTypes[$selectedThreadIndex] -eq "safe") { 1 } else { 0 }

    # Prompt user to select architecture
    $archTypes = @("86", "64")
    Write-Output "Select architecture type:"
    for ($i = 0; $i -lt $archTypes.Length; $i++) {
        Write-Output "[$($i + 1)]  $($archTypes[$i])"
    }
    do {
        $selection = Read-Host "Enter the number corresponding to your choice"
        $selectedArchIndex = $selection - 1  # Convert to 0-based index
        if ($selectedArchIndex -lt 0 -or $selectedArchIndex -ge $archTypes.Length) {
            Write-Output "Invalid choice. Please enter a number between 1 and $($archTypes.Length)."
        }
    } until ($selectedArchIndex -ge 0 -and $selectedArchIndex -lt $archTypes.Length)
    $arch = $archTypes[$selectedArchIndex]

    # Prompt user to select installation level
    $installLevels = @("User", "Machine")
    Write-Output "Select installation level:"
    for ($i = 0; $i -lt $installLevels.Length; $i++) {
        Write-Output "[$($i + 1)]  $($installLevels[$i])"
    }
    do {
        $selection = Read-Host "Enter the number corresponding to your choice"
        $selectedLevelIndex = $selection - 1  # Convert to 0-based index
        if ($selectedLevelIndex -lt 0 -or $selectedLevelIndex -ge $installLevels.Length) {
            Write-Output "Invalid choice. Please enter a number between 1 and $($installLevels.Length)."
        }
    } until ($selectedLevelIndex -ge 0 -and $selectedLevelIndex -lt $installLevels.Length)
    $installLevel = $installLevels[$selectedLevelIndex]

    return @{
        Version = $phpVersion
        ThreadSafe = $threadSafe
        Architecture = $arch
        InstallLevel = $installLevel
    }
}

# Install PHP using PHP Manager
function Install-PHP {
    param (
        [string]$phpVersion,
        [int]$threadSafe,
        [string]$arch,
        [string]$installLevel
    )
    $installPath = "C:\PHP\$phpVersion"
    Write-Output "Installing PHP version $phpVersion using PHP Manager..."
    try {
        Install-Php -Version $phpVersion -Architecture $arch -ThreadSafe $threadSafe -Path $installPath -TimeZone UTC -AddToPath $installLevel
        Write-Output "PHP version $phpVersion installed successfully."
    } catch {
        Write-Warning "Failed to install PHP version $phpVersion. Please check the PHP Manager module."
        return $false
    }
    return $true
}

# Add or update the PATH environment variable
function Update-EnvironmentPath {
    param(
        [string]$pathToAdd,
        [EnvironmentVariableTarget]$target = [EnvironmentVariableTarget]::Machine  # Update to Machine level for global availability
    )
    $currentPath = [Environment]::GetEnvironmentVariable("Path", $target)
    if (-not ($currentPath -like "*$pathToAdd*")) {
        $newPath = "$pathToAdd;$currentPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, $target)
        Write-Output "PATH environment variable updated."
    }
}

# --- Main Script Logic ---

# Check and install PHP Manager module
if (-not (Check-PHPManager)) {
    Install-PHPManager
}

# Check and Install PHP using PHP Manager
if (-not (Test-Command "php")) {
    $phpOptions = Select-PHP
    Write-Output "PHP not found. Installing PHP version $($phpOptions.Version)..."
    if (-not (Install-PHP -phpVersion $phpOptions.Version -threadSafe $phpOptions.ThreadSafe -arch $phpOptions.Architecture -installLevel $phpOptions.InstallLevel)) {
        Write-Output "PHP installation failed. Please try again or install PHP manually."
        exit 1
    }
} else {
    Write-Output "PHP is already installed."
}

# Check and Install Composer
if (-not (Check-Composer)) {
    Install-Composer
}

# Run Laravel commands (updated for ampersand)
$command = "cmd.exe /k cd `"$projectPath`" &`& php composer install &`& php artisan migrate"

# Run the command in a new CMD window
Invoke-Expression $command