# Description: This script checks the availability of certain required packages (like 'curl' and 'jq'), makes sure certain directories exist, fetches the software releases 'gh-cli' and 'yq' from GitHub, then downloads, extracts, and installs them if not already available in a specific tool cache directory. It then defines new path variables that include the path of the recent installations and adds them to the system's PATH variable.

param(
  [string]$RUNNER_TEMP = "C:\temp",
  [string]$RUNNER_TOOL_CACHE = "C:\tool-cache"
)

# Enable debug output if RUNNER_DEBUG or RUNNER_VERBOSE is set
$VerboseEnabled = $false
if ($env:RUNNER_DEBUG -eq 1 -or $env:RUNNER_VERBOSE -eq 1) {
  $VerboseEnabled = $true
  $DebugPreference = "Continue"
  $VerbosePreference = "Continue"
}

Write-Host "::group::Checking dependencies"

# Function to check if a package is installed via Chocolatey
function Test-ChocolateyPackageInstalled {
    param([string]$PackageName)
    
    $pkg = choco list --local-only $PackageName --exact --limit-output
    return $pkg -ne $null -and $pkg -ne ""
}

# Function to get Chocolatey package name for a command
function Get-PackageName {
    param([string]$Command)
    
    # Map of commands to their package names
    $packageMap = @{
        'curl' = 'curl'
        'jq' = 'jq'
        # Add more mappings here as needed
    }
    
    if ($packageMap.ContainsKey($Command)) {
        return $packageMap[$Command]
    }
    # Default: return command name as package name
    return $Command
}

# Function to normalize package list (handles both space and newline separated lists)
function Normalize-PackageList {
    param([string]$InputList)
    
    # Split on both spaces and newlines, then join with spaces
    $normalized = $InputList -split '[\s\n]+' | Where-Object { $_ -ne '' }
    return $normalized
}

# Function to install a package with Chocolatey
function Install-ChocolateyPackage {
    param(
        [string]$Package,
        [string]$Version
    )
    
    if ($Version) {
        choco install -y $Package --version $Version
    } else {
        choco install -y $Package
    }
}

# Function to check if a package is installed with the specified version
function Test-ChocolateyPackage {
    param(
        [string]$Package,
        [string]$Version
    )
    
    $installed = choco list --local-only $Package
    if ($Version) {
        return $installed -match "$Package\s+$Version"
    }
    return $installed -match "^$Package\s+"
}

# Ensure directories exist
New-Item -ItemType Directory -Force -Path $RUNNER_TEMP, $RUNNER_TOOL_CACHE | Out-Null

# Define base packages
$basePackages = @("curl", "jq")
$packagesToInstall = @()
$installedPackages = @()

# Process each package specification
$allPackages = $basePackages
if ($env:INPUT_INCLUDE_PACKAGES) {
    if ($VerboseEnabled) {
        Write-Host "Adding additional packages: $($env:INPUT_INCLUDE_PACKAGES)"
    }
    $additionalPackages = Normalize-PackageList $env:INPUT_INCLUDE_PACKAGES
    $allPackages += $additionalPackages
    if ($VerboseEnabled) {
        Write-Host "All packages to check/install: $($allPackages -join ', ')"
    }
}

Write-Host "::group::Checking and installing required packages"
foreach ($entry in $allPackages) {
    $cmd = $null
    $pkg = $null
    $version = $null
    
    # Parse the entry format: [command:]package[=version]
    if ($entry -match '^([^:]+):([^=]+)(=(.+))?$') {
        # Format: command:package[=version]
        $cmd = $matches[1]
        $pkg = $matches[2]
        $version = $matches[4]
    } elseif ($entry -match '^([^=]+)(=(.+))?$') {
        # Format: package[=version]
        $cmd = $matches[1]
        $pkg = $matches[1]
        $version = $matches[3]
    }
    
    # Skip if command exists
    if (Get-Command -Name $cmd -ErrorAction SilentlyContinue) {
        if ($VerboseEnabled) {
            Write-Host "Command '$cmd' already exists, skipping installation"
        }
        continue
    }
    
    # Add to installation list
    if ($version) {
        $packagesToInstall += @{
            Package = $pkg
            Version = $version
        }
    } else {
        $packagesToInstall += @{
            Package = $pkg
            Version = $null
        }
    }
}

# Install missing packages
if ($packagesToInstall.Count -gt 0) {
    Write-Host "Installing packages: $($packagesToInstall | ForEach-Object { "$($_.Package) $(if ($_.Version) {"v$($_.Version)"})" } | Join-String -Separator ", ")"
    
    foreach ($package in $packagesToInstall) {
        Write-Host "Installing package: $($package.Package) $(if ($package.Version) { "version $($package.Version)" })"
        Install-ChocolateyPackage -Package $package.Package -Version $package.Version
        
        # Add to installed packages list
        if ($package.Version) {
            $installedPackages += "$($package.Package)=$($package.Version)"
        } else {
            $installedPackages += $package.Package
        }
    }
    
    # Record installed packages to GITHUB_ENV
    if ($installedPackages.Count -gt 0) {
        Add-Content -Path $env:GITHUB_ENV -Value "INSTALLED_WINDOWS_PACKAGES=$($installedPackages -join ',')"
        Write-Host "Successfully installed: $($installedPackages -join ', ')"
    }
} else {
    Write-Host "No packages need to be installed"
}
Write-Host "::endgroup::"

# Fetch the latest versions
Write-Host "::group::Setting up GitHub CLI"
Write-Host "Fetching the latest GitHub CLI version..."
$GH_CLI_VERSION = (curl -Ls https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name')
Write-Host "Latest GitHub CLI version: $GH_CLI_VERSION"
Write-Host "::endgroup::"

Write-Host "::group::Setting up yq YAML processor"
Write-Host "Fetching the latest yq version..."
$YQ_VERSION = (curl -Ls https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.tag_name')
Write-Host "Latest yq version: $YQ_VERSION"
Write-Host "::endgroup::"

# Record tool versions to GITHUB_ENV
Add-Content -Path $env:GITHUB_ENV -Value "GH_CLI_VERSION=$GH_CLI_VERSION"
Add-Content -Path $env:GITHUB_ENV -Value "YQ_VERSION=$YQ_VERSION"

# Extract the version number without the 'v' prefix
$GH_CLI_VERSION_NUMBER = $GH_CLI_VERSION.TrimStart('v')

$os = 'windows'
switch ($env:RUNNER_ARCH) {
  'X86'   { $arch = '386' }
  'X64'   { $arch = 'amd64' }
  'ARM64' { $arch = 'arm64' }
  default { 
    Write-Host "::error::Cannot handle arch of type $env:RUNNER_ARCH. Expected one of: [ X86 X64 ARM64 ]"
    throw "Cannot handle arch of type $env:RUNNER_ARCH. Expected one of: [ X86 X64 ARM64 ]"
  }
}

Write-Host "::group::Installing tools"
Write-Host "Detected architecture: $arch"

# Define the gh-cli and yq binary names
$gh_cli_binary = "bin/gh.exe"
$yq_binary = "yq.exe"

$gh_cli_path = "$RUNNER_TOOL_CACHE\gh-cli\$GH_CLI_VERSION\$os`_$arch"
$gh_cli_temp_path = "$RUNNER_TEMP\gh-cli-temp"

# Check if gh-cli is already in the tool cache
if (-not (Test-Path -Path "$gh_cli_path\gh.exe")) {
    Write-Host "gh-cli not found in cache. Proceeding with download and installation."
    New-Item -ItemType Directory -Force -Path $gh_cli_path | Out-Null
    New-Item -ItemType Directory -Force -Path $gh_cli_temp_path | Out-Null

    $gh_cli_url = "https://github.com/cli/cli/releases/download/$GH_CLI_VERSION/gh_${GH_CLI_VERSION_NUMBER}_${os}_${arch}.zip"
    Invoke-WebRequest -Uri $gh_cli_url -OutFile "$RUNNER_TEMP\gh_${GH_CLI_VERSION_NUMBER}_${os}_${arch}.zip"

    # Extract the archive to the temporary location
    Expand-Archive -Path "$RUNNER_TEMP\gh_${GH_CLI_VERSION_NUMBER}_${os}_${arch}.zip" -DestinationPath "$gh_cli_temp_path"

    # Move the gh binary to the desired location
    Move-Item -Path "$gh_cli_temp_path\bin\gh.exe" -Destination "$gh_cli_path\gh.exe" -Force

    # Clean up the temporary files
    Remove-Item -Recurse -Force $gh_cli_temp_path
    Remove-Item -Force "$RUNNER_TEMP\gh_${GH_CLI_VERSION_NUMBER}_${os}_${arch}.zip"
} else {
    Write-Host "gh-cli found in cache at $gh_cli_path"
}

# Check if yq is already in the tool cache
$yq_path = "$RUNNER_TOOL_CACHE\yq\$YQ_VERSION\$os`_$arch"
if (-not (Test-Path -Path "$yq_path\$yq_binary")) {
  Write-Host "yq not found in cache. Proceeding with download and installation."
  New-Item -ItemType Directory -Force -Path $yq_path | Out-Null

  $yq_url = "https://github.com/mikefarah/yq/releases/download/$YQ_VERSION/yq_${os}_${arch}.exe"
  Invoke-WebRequest -Uri $yq_url -OutFile "$yq_path\$yq_binary"
} else {
  Write-Host "yq found in cache at $yq_path"
}

# Define paths
$combinedPaths = "$gh_cli_path;$yq_path"

# Write combined paths to GITHUB_PATH
$combinedPaths | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append

# Optionally, update the PATH for the current process
[System.Environment]::SetEnvironmentVariable('PATH', "$combinedPaths;$env:PATH", [System.EnvironmentVariableTarget]::Process)

Write-Host "::endgroup::"
Write-Host "::endgroup::"
