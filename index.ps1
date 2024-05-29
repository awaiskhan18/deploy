# Define project path (you could make this a parameter for flexibility)
$projectPath = Get-Location

# --- Functions ---

# Check if a command exists
function Test-Command {
    param ([string]$CommandName)
    return (Get-Command $CommandName -ErrorAction SilentlyContinue) -ne $null
}

# Check PHP (without assuming path)
function Check-PHP {
    return (Test-Command "php")
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

# Array of available PHP versions
$phpVersions = @("8.2.12", "8.1.20", "8.0.28", "7.4.33")

# Array of corresponding VS versions
$vsVersions = @("16", "16", "16", "15")

# Function to map PHP version to VS version
function Get-VsVersionForPHP {
    param ([string]$phpVersion)

    $index = [array]::IndexOf($phpVersions, $phpVersion)
    if ($index -ge 0) {
        return $vsVersions[$index]
    } else {
        Write-Warning "No VS runtime version found for PHP $phpVersion."
        return $null
    }
}

# Install PHP (modified to use the mapping function and version-specific directory)
function Install-PHP {
    param ([string]$phpVersion)
    Write-Output "Installing PHP version $phpVersion..."

    # Base URL for PHP downloads (updated)
    $phpBaseUrl = "https://windows.php.net/downloads/releases/archives/"

    # Get the corresponding VS version
    $vsVersion = Get-VsVersionForPHP -phpVersion $phpVersion
    if (-not $vsVersion) {
        Write-Warning "Please double-check the version or try again later."
        return $false
    }

    $phpInstallerUrl = "$phpBaseUrl/php-$phpVersion-nts-Win32-vs$vsVersion-x64.zip"
    $tempDirectory = (Get-Item -Path $env:TEMP).FullName
    $phpZipPath = "$tempDirectory\php.zip"
    # Version-specific PHP installation directory
    $phpInstallPath = "C:\php\php-$phpVersion"  # Updated path

    # Download PHP
    Invoke-WebRequest -Uri $phpInstallerUrl -OutFile $phpZipPath

    # Extract PHP to the version-specific directory
    Expand-Archive -Path $phpZipPath -DestinationPath $phpInstallPath -Force

    # Clean up
    Remove-Item -Path $phpZipPath -Force

    # Add PHP to PATH (crucial!)
    if (-Not (Test-Path "$phpInstallPath\php.exe")) {  # Check if php.exe exists
        Write-Warning "php.exe not found in $phpInstallPath. Installation might have failed."
        return $false
    }
    Update-EnvironmentPath -pathToAdd $phpInstallPath
    # Verify if PHP is now available
    return (Check-PHP)
}

# Prompt the user to select the PHP version (modified)
function Select-PHPVersion {

    # Prompt user to choose the version to install
    do {
        $selection = Read-Host "Enter the number corresponding to your choice"
        $selectedIndex = $selection - 1  # Convert to 0-based index
        if ($selectedIndex -lt 0 -or $selectedIndex -ge $phpVersions.Length) {
            Write-Output "Invalid choice. Please enter a number between 1 and $($phpVersions.Length)."
        }
    } until ($selectedIndex -ge 0 -and $selectedIndex -lt $phpVersions.Length)

    return $phpVersions[$selectedIndex]
}

# Add or update the PATH environment variable
function Update-EnvironmentPath {
    param(
        [string]$pathToAdd,
        [EnvironmentVariableTarget]$target = [EnvironmentVariableTarget]::Process  # Default to Process
    )
    $currentPath = [Environment]::GetEnvironmentVariable("Path", $target)
    if (-not ($currentPath -like "*$pathToAdd*")) {
        $newPath = "$pathToAdd;$currentPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, $target)
        Write-Output "PATH environment variable updated."
    }
}

#Display the available PHP versions for the user to choose from
Write-Output "Available PHP versions:"
for ($i = 0; $i -lt $phpVersions.Length; $i++) {
    Write-Output "[$($i + 1)]  $($phpVersions[$i])"
}

# --- Main Script Logic ---

# Check and Install PHP
if (-not (Check-PHP)) {
    # Only show the version selection prompt if PHP needs to be installed
    $selectedPHPVersion = Select-PHPVersion

    Write-Output "PHP not found. Installing PHP version $selectedPHPVersion..."

    if (-not (Install-PHP -phpVersion $selectedPHPVersion)) {
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
