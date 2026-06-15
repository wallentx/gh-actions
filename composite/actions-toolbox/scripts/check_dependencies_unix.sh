#!/usr/bin/env bash
set -euo pipefail

# Description: This script checks if certain packages ('curl', 'jq', and 'envsubst') are installed and if not, attempts to install them using the appropriate package manager (Homebrew for macOS or other package managers for Linux). It then fetches the latest versions of GitHub CLI and 'yq', checks if they exist in the tool cache or, if not, downloads and installs them. It then adds the path to the installed software to the tool path.

# Global Variables
RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
RUNNER_TOOL_CACHE="${RUNNER_TOOL_CACHE:-/opt/hostedtoolcache}"
TOOLPATH=""
ADDITIONAL_PACKAGES="${INPUT_INCLUDE_PACKAGES:-}"

# Enable debug output if RUNNER_DEBUG is set
if [[ ${RUNNER_DEBUG:-0} -eq 1 ]]; then
  set -x
fi

# Print additional packages if verbose mode is enabled
if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
  echo "Additional packages to install: ${ADDITIONAL_PACKAGES}"
fi

# Error Handler
error_handler() {
  echo "An error occurred in ${BASH_SOURCE[0]} at line $1. Exiting gracefully." >&2
  exit 1
}
trap 'error_handler $LINENO' ERR

# Function to check if a command exists
command_exists() {
  command -v "$1" > /dev/null 2>&1
}

# Function to parse package specifications into components
parse_package_spec() {
  local spec="$1"
  local separator="$2"
  
  # Check if the argument is in the format command:package=version
  if [[ "$spec" =~ ^([^:]+):([^=]+)(=(.+))?$ ]]; then
    # Format: command:package[=version]
    local cmd="${BASH_REMATCH[1]}"
    local pkg="${BASH_REMATCH[2]}"
    local version="${BASH_REMATCH[4]}"
    
    if [ -n "$version" ]; then
      echo "${pkg}${separator}${version}"
    else
      echo "$pkg"
    fi
  # Check if the argument is in the format package=version
  elif [[ "$spec" =~ ^([^=]+)(=(.+))?$ ]]; then
    # Format: package[=version]
    local pkg="${BASH_REMATCH[1]}"
    local version="${BASH_REMATCH[3]}"
    
    if [ -n "$version" ]; then
      echo "${pkg}${separator}${version}"
    else
      echo "$pkg"
    fi
  else
    # Plain package name
    echo "$spec"
  fi
}

# Function to install required packages on Linux
install_packages_linux() {
  local packages=()
  local installed_packages=()
  
  echo "::group::Installing Linux packages"
  
  # Process each package argument
  for arg in $1; do
    # Fix shellcheck warning SC2207 by using read
    local parsed_pkg
    parsed_pkg=$(parse_package_spec "$arg" "=")
    packages+=("$parsed_pkg")
  done

  if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
  else
    SUDO=$(command_exists sudo && echo "sudo" || echo "")
  fi

  if command_exists apk; then
    ${SUDO} apk add --no-cache "${packages[@]}"
    installed_packages+=("${packages[@]}")
  elif command_exists apt-get; then
    ${SUDO} apt update
    ${SUDO} apt-get install -y "${packages[@]}"
    installed_packages+=("${packages[@]}")
  elif command_exists dnf; then
    ${SUDO} dnf install -y "${packages[@]}"
    installed_packages+=("${packages[@]}")
  elif command_exists yum; then
    ${SUDO} yum install -y "${packages[@]}"
    installed_packages+=("${packages[@]}")
  elif command_exists zypper; then
    ${SUDO} zypper install -n "${packages[@]}"
    installed_packages+=("${packages[@]}")
  elif command_exists pacman; then
    ${SUDO} pacman -S --needed --noconfirm "${packages[@]}"
    installed_packages+=("${packages[@]}")
  else
    echo "FAILED TO INSTALL required packages: ${packages[*]}" >&2
    echo "::endgroup::"
    return 1
  fi
  
  # Record installed packages to GITHUB_ENV for later steps
  if [ ${#installed_packages[@]} -gt 0 ]; then
    echo "INSTALLED_LINUX_PACKAGES=${installed_packages[*]}" >> "$GITHUB_ENV"
    echo "Successfully installed: ${installed_packages[*]}"
  fi
  
  echo "::endgroup::"
}

# Function to install required packages on macOS using Homebrew
install_packages_macos() {
  local packages=()
  local installed_packages=()
  
  echo "::group::Installing macOS packages"
  
  # Process each package argument
  for arg in $1; do
    # Fix shellcheck warning SC2207 by using read
    local parsed_pkg
    parsed_pkg=$(parse_package_spec "$arg" "@")
    packages+=("$parsed_pkg")
  done

  # Ensure Homebrew is installed
  if ! command_exists brew; then
    echo "Homebrew is not installed. Installing Homebrew."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH for the current script session
    eval "$(brew shellenv)"
  fi

  # Update Homebrew to ensure the latest package information
  brew update

  # Install the required packages
  brew install "${packages[@]}"
  installed_packages+=("${packages[@]}")
  
  # Record installed packages to GITHUB_ENV for later steps
  if [ ${#installed_packages[@]} -gt 0 ]; then
    echo "INSTALLED_MACOS_PACKAGES=${installed_packages[*]}" >> "$GITHUB_ENV"
    echo "Successfully installed: ${installed_packages[*]}"
  fi
  
  echo "::endgroup::"
}

# Function to normalize package list (handles both space and newline separated lists)
normalize_package_list() {
  echo "$1" | tr '\n' ' ' | tr -s ' ' | sed 's/^ *//;s/ *$//'
}

# Function to install a package
install_packages() {
  if [[ "$RUNNER_OS" == "Linux" ]]; then
    install_packages_linux "$1"
  elif [[ "$RUNNER_OS" == "macOS" ]]; then
    install_packages_macos "$1"
  else
    echo "::error::Unsupported OS: $RUNNER_OS"
    exit 1
  fi
}

# Function to check and install dependencies
check_and_install_dependencies() {
  local packages_to_install=()
  
  # Process each package specification
  for entry in $1; do
    local cmd=""
    local pkg=""
    local version=""
    
    # Parse the entry format: [command:]package[=version]
    if [[ "$entry" =~ ^([^:]+):([^=]+)(=(.+))?$ ]]; then
      # Format: command:package[=version]
      cmd="${BASH_REMATCH[1]}"
      pkg="${BASH_REMATCH[2]}"
      version="${BASH_REMATCH[4]}"
    elif [[ "$entry" =~ ^([^=]+)(=(.+))?$ ]]; then
      # Format: package[=version]
      cmd="${BASH_REMATCH[1]}"
      pkg="${BASH_REMATCH[1]}"
      version="${BASH_REMATCH[3]}"
    fi
    
    # Skip if command exists
    if command_exists "$cmd"; then
      if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
        echo "Command '$cmd' found, skipping package installation"
      fi
      continue
    fi
    
    # Add to installation list with version if specified
    if [ -n "$version" ]; then
      packages_to_install+=("$pkg=$version")
    else
      packages_to_install+=("$pkg")
    fi
  done
  
  # Install missing packages if any
  if [ ${#packages_to_install[@]} -gt 0 ]; then
    echo "Installing packages: ${packages_to_install[*]}"
    install_packages "${packages_to_install[*]}"
  fi
}

# Function to fetch the latest version from GitHub API
fetch_latest_version() {
  local repo="$1"
  local response tag

  if ! response="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")"; then
    echo "Failed to fetch latest release metadata for $repo." >&2
    return 1
  fi

  if ! tag="$(printf '%s' "$response" | jq -er 'objects.tag_name | select(type == "string" and length > 0)' 2>/dev/null)"; then
    echo "Release metadata for $repo was not valid JSON with a non-empty tag_name." >&2
    return 1
  fi

  printf '%s\n' "$tag"
}

# Function to append a directory to the tool path list
append_toolpath() {
  local path="$1"

  if [[ -z "$path" ]]; then
    return
  fi

  if [[ -z "$TOOLPATH" ]]; then
    TOOLPATH="$path"
  else
    TOOLPATH="${TOOLPATH}:${path}"
  fi
}

# Function to detect the existing GitHub CLI version
detect_existing_gh_version() {
  gh --version 2>/dev/null | awk '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^v?[0-9]+([.][0-9]+)+([-][A-Za-z0-9._-]+)?$/) {
          version = $i
          if (version !~ /^v/) {
            version = "v" version
          }
          print version
          exit
        }
      }
    }
  '
}

# Function to determine architecture
determine_arch() {
  case "$RUNNER_ARCH" in
    'X86') echo '386' ;;
    'X64') echo 'amd64' ;;
    'ARM') echo 'armv6' ;;
    'ARM64') echo 'arm64' ;;
    *)
      echo "Unsupported architecture: $RUNNER_ARCH" >&2
      exit 1
      ;;
  esac
}

# Function to install GitHub CLI
install_gh_cli() {
  local version="$1"
  local os="$2"
  local arch="$3"

  local gh_cli_binary="gh"
  local gh_cli_archive_binary="bin/gh"
  local gh_cli_path="${RUNNER_TOOL_CACHE}/gh-cli/${version}/${os}_${arch}"

  if [ ! -f "${gh_cli_path}/${gh_cli_binary}" ]; then
    echo "gh-cli not found in cache. Downloading and installing..."
    mkdir -p "${gh_cli_path}"
    local gh_cli_archive="gh_${version#v}_${os}_${arch}.tar.gz"
    local gh_cli_url="https://github.com/cli/cli/releases/download/${version}/gh_${version#v}_${os}_${arch}.tar.gz"
    curl -fsSL "${gh_cli_url}" -o "${RUNNER_TEMP}/${gh_cli_archive}"
    tar -xzf "${RUNNER_TEMP}/${gh_cli_archive}" -C "${gh_cli_path}" "gh_${version#v}_${os}_${arch}/${gh_cli_archive_binary}" --transform='s|.*/||'
  else
    echo "gh-cli found in cache at ${gh_cli_path}"
  fi

  append_toolpath "${gh_cli_path}"
}

# Function to install yq
install_yq() {
  local version="$1"
  local os="$2"
  local arch="$3"

  local yq_binary="yq"
  local yq_path="${RUNNER_TOOL_CACHE}/yq/${version}/${os}_${arch}"

  if [ ! -f "${yq_path}/${yq_binary}" ]; then
    echo "yq not found in cache. Downloading and installing..."
    mkdir -p "${yq_path}"
    local yq_url="https://github.com/mikefarah/yq/releases/download/${version}/yq_${os}_${arch}"
    curl -fsSL "${yq_url}" -o "${RUNNER_TEMP}/yq_${os}_${arch}"
    mv "${RUNNER_TEMP}/yq_${os}_${arch}" "${yq_path}/${yq_binary}"
    chmod +x "${yq_path}/${yq_binary}"
  else
    echo "yq found in cache at ${yq_path}"
  fi

  append_toolpath "${yq_path}"
}

# Function to update the PATH
update_path() {
  if [[ -n "$TOOLPATH" ]]; then
    echo "${TOOLPATH}" >> "$GITHUB_PATH"
  fi
}

# Main Execution Flow
main() {
  echo '::group::Checking dependencies'

  # Base packages required for the action
  basePackages="curl jq wget envsubst:gettext"

  # Combine base packages with additional packages
  allPackages="$basePackages"
  if [ -n "$ADDITIONAL_PACKAGES" ]; then
    if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
      echo "Adding additional packages: $ADDITIONAL_PACKAGES"
    fi
    normalized_packages=$(normalize_package_list "$ADDITIONAL_PACKAGES")
    allPackages="$allPackages $normalized_packages"
    if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
      echo "All packages to check/install: $allPackages"
    fi
  fi

  # Check and install all packages
  check_and_install_dependencies "$allPackages"

  local gh_cli_version yq_version arch os gh_cli_install_required gh_cli_path

  echo "::group::Setting up GitHub CLI"
  if command_exists gh; then
    gh_cli_path="$(command -v gh)"
    gh_cli_version="$(detect_existing_gh_version || true)"
    gh_cli_version="${gh_cli_version:-unknown}"
    gh_cli_install_required=0
    echo "GitHub CLI found on PATH at ${gh_cli_path}"
    echo "Detected GitHub CLI version: $gh_cli_version"
  else
    gh_cli_install_required=1
    echo "GitHub CLI not found on PATH. Fetching latest GitHub CLI version..."
    gh_cli_version=$(fetch_latest_version "cli/cli")
    echo "Latest GitHub CLI version: $gh_cli_version"
  fi
  echo "::endgroup::"

  echo "::group::Setting up yq YAML processor"
  echo "Fetching the latest yq version..."
  yq_version=$(fetch_latest_version "mikefarah/yq")
  echo "Latest yq version: $yq_version"
  echo "::endgroup::"

  # Record tool versions to GITHUB_ENV for later steps
  echo "GH_CLI_VERSION=$gh_cli_version" >> "$GITHUB_ENV"
  echo "YQ_VERSION=$yq_version" >> "$GITHUB_ENV"

  echo "::group::Installing tools"
  os="$(echo "$RUNNER_OS" | tr '[:upper:]' '[:lower:]')"  # 'linux' or 'macos'
  arch=$(determine_arch)
  echo "Detected architecture: $arch"

  if [[ "$gh_cli_install_required" -eq 1 ]]; then
    install_gh_cli "$gh_cli_version" "$os" "$arch"
  else
    echo "Using existing GitHub CLI; skipping installation."
  fi
  install_yq "$yq_version" "$os" "$arch"

  update_path
  echo "::endgroup::"

  echo '::endgroup::'
}

# Invoke main
main
