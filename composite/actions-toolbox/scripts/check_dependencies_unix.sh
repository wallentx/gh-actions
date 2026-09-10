#!/usr/bin/env bash
set -euo pipefail

# Description: This script checks if certain packages ('curl', 'jq', and 'envsubst') are installed and if not, attempts to install them using the appropriate package manager (Homebrew for macOS or other package managers for Linux). It then fetches the latest versions of GitHub CLI and 'yq', checks if they exist in the tool cache or, if not, downloads and installs them. It then adds the path to the installed software to the tool path.

# Global Variables
RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
RUNNER_TOOL_CACHE="${RUNNER_TOOL_CACHE:-/opt/hostedtoolcache}"
TOOLPATH=""
ADDITIONAL_PACKAGES="${INPUT_INCLUDE_PACKAGES:-}"
GITHUB_RELEASE_INSTALLS=()

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

# Fetch release metadata. Explicit versions accept either v1.2.3 or 1.2.3,
# regardless of which spelling the repository uses for its tag.
fetch_release_metadata() {
  local repo="$1"
  local requested_version="${2:-}"
  local response tag encoded_tag alternative_tag

  if [ -z "$requested_version" ]; then
    if ! response="$(gh api "repos/${repo}/releases/latest")"; then
      echo "Failed to fetch latest release metadata for ${repo}." >&2
      return 1
    fi
  else
    alternative_tag="v${requested_version#v}"
    if [[ "$requested_version" == v* ]]; then
      alternative_tag="${requested_version#v}"
    fi

    for tag in "$requested_version" "$alternative_tag"; do
      encoded_tag="$(jq -rn --arg value "$tag" '$value | @uri')"
      if response="$(gh api "repos/${repo}/releases/tags/${encoded_tag}" 2>/dev/null)"; then
        break
      fi
      response=""
    done

    if [ -z "$response" ]; then
      echo "Could not find release '${requested_version}' in ${repo}." >&2
      return 1
    fi
  fi

  if ! jq -e 'objects | (.tag_name | type == "string" and length > 0) and (.assets | type == "array")' \
    >/dev/null 2>&1 <<<"$response"; then
    echo "Release metadata for ${repo} was not valid or did not contain assets." >&2
    return 1
  fi

  printf '%s\n' "$response"
}

release_name_tokens() {
  local value
  value="$(tr '[:upper:]' '[:lower:]' <<<"$1")"
  value="${value//x86_64/amd64}"
  value="${value//x86-64/amd64}"
  value="${value//[^[:alnum:]]/ }"
  value="$(tr -s ' ' <<<"$value")"
  printf ' %s ' "$value"
}

tokens_contain() {
  local needle
  needle="$(release_name_tokens "$2")"
  [[ "$1" == *"$needle"* ]]
}

value_in_list() {
  local needle="$1"
  shift
  local value
  for value in "$@"; do
    [[ "$value" == "$needle" ]] && return 0
  done
  return 1
}

release_os_aliases() {
  case "$1" in
    linux) echo 'linux' ;;
    macos) echo 'darwin macos osx' ;;
    *) echo "$1" ;;
  esac
}

release_arch_aliases() {
  case "$1" in
    amd64) echo 'amd64 x86_64 x64' ;;
    386) echo '386 i386 i686 x86' ;;
    arm64) echo 'arm64 aarch64' ;;
    armv6) echo 'armv6 arm6' ;;
    *) echo "$1" ;;
  esac
}

tokens_match_any() {
  local tokens="$1"
  shift
  local alias
  for alias in "$@"; do
    if tokens_contain "$tokens" "$alias"; then
      return 0
    fi
  done
  return 1
}

# Score a release asset for the current platform. The command and repository
# names are hints, not requirements, so generically named bundles still work.
score_release_asset() {
  local name="$1" tool="$2" repo_name="$3" os="$4" arch="$5"
  local lower tokens tool_token repo_token alias score=0
  local desired_os desired_arch

  lower="$(tr '[:upper:]' '[:lower:]' <<<"$name")"
  tokens="$(release_name_tokens "$name")"
  tool_token="$(tr '[:upper:]' '[:lower:]' <<<"$tool")"
  repo_token="$(tr '[:upper:]' '[:lower:]' <<<"$repo_name")"

  case "$lower" in
    *checksum*|*sha256*|*sha512*|*.sig|*.asc|*.pem|*.minisig|*.sbom*|*.json|*.md|*.txt)
      echo -10000
      return
      ;;
    *.deb|*.rpm|*.apk|*.pkg|*.dmg|*.msi|*.exe)
      echo -10000
      return
      ;;
  esac

  if tokens_contain "$tokens" source || tokens_contain "$tokens" sources; then
    echo -10000
    return
  fi

  read -r -a desired_os <<<"$(release_os_aliases "$os")"
  read -r -a desired_arch <<<"$(release_arch_aliases "$arch")"

  if tokens_match_any "$tokens" "${desired_os[@]}"; then
    score=$((score + 60))
  fi
  if tokens_match_any "$tokens" "${desired_arch[@]}"; then
    score=$((score + 55))
  fi

  for alias in linux darwin macos osx windows win32 win64 freebsd openbsd netbsd; do
    if tokens_contain "$tokens" "$alias" && ! value_in_list "$alias" "${desired_os[@]}"; then
      echo -10000
      return
    fi
  done
  for alias in amd64 x86_64 x64 386 i386 i686 arm64 aarch64 armv6 armv7 ppc64 ppc64le s390x; do
    if tokens_contain "$tokens" "$alias" && ! value_in_list "$alias" "${desired_arch[@]}"; then
      echo -10000
      return
    fi
  done

  tokens_contain "$tokens" "$tool_token" && score=$((score + 45))
  tokens_contain "$tokens" "$repo_token" && score=$((score + 30))

  case "$lower" in
    *.tar.gz|*.tgz) score=$((score + 16)) ;;
    *.tar) score=$((score + 15)) ;;
    *.zip) score=$((score + 14)) ;;
    *.tar.xz|*.txz) score=$((score + 13)) ;;
    *.tar.bz2|*.tbz2) score=$((score + 12)) ;;
    *.tar.zst|*.tzst) score=$((score + 11)) ;;
    *.gz) score=$((score + 8)) ;;
    *.xz) score=$((score + 7)) ;;
    *.bz2) score=$((score + 6)) ;;
    *.zst) score=$((score + 5)) ;;
  esac

  echo "$score"
}

# Print "asset-name<TAB>asset-id" for the strongest unambiguous asset match in
# release metadata.
select_release_asset() {
  local metadata="$1" tool="$2" repo="$3" os="$4" arch="$5"
  local repo_name="${repo##*/}"
  local name asset_id score
  local best_name="" best_asset_id="" best_score=-10001 tied=0
  local candidates=""

  while IFS=$'\t' read -r name asset_id; do
    [ -n "$name" ] || continue
    score="$(score_release_asset "$name" "$tool" "$repo_name" "$os" "$arch")"
    [ "$score" -gt -10000 ] || continue
    candidates+="  score=${score}  ${name}"$'\n'
    if [ "$score" -gt "$best_score" ]; then
      best_score="$score"
      best_name="$name"
      best_asset_id="$asset_id"
      tied=0
    elif [ "$score" -eq "$best_score" ]; then
      tied=1
    fi
  done < <(jq -r '.assets[] | [.name, (.id | tostring)] | @tsv' <<<"$metadata")

  if [ -z "$best_name" ]; then
    echo "No usable release assets were found for ${repo} on ${os}/${arch}." >&2
    return 1
  fi
  if [ "$tied" -eq 1 ]; then
    echo "Could not choose an unambiguous release asset for ${tool} from ${repo}." >&2
    printf '%s' "$candidates" >&2
    return 1
  fi

  if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
    echo "Selected release asset '${best_name}' (score ${best_score})." >&2
  fi
  printf '%s\t%s\n' "$best_name" "$best_asset_id"
}

validate_archive_paths() {
  local path
  while IFS= read -r path; do
    path="${path#./}"
    [[ -z "$path" || "$path" == '.' ]] && continue
    case "$path" in
      /*|..|../*|*/../*|*/..|*\\*)
        echo "Refusing unsafe archive member: ${path}" >&2
        return 1
        ;;
    esac
  done
}

# Expand common archive/compression formats. Raw assets are copied as-is.
extract_release_asset() {
  local asset_path="$1" asset_name="$2" destination="$3"
  local safe_name lower output_name
  safe_name="${asset_name##*/}"
  if [[ -z "$safe_name" || "$safe_name" == '.' || "$safe_name" == '..' ]]; then
    echo "Release asset has an unsafe filename: '${asset_name}'." >&2
    return 1
  fi
  lower="$(tr '[:upper:]' '[:lower:]' <<<"$safe_name")"
  mkdir -p "$destination"

  case "$lower" in
    *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tbz2|*.tar.zst|*.tzst)
      tar -tf "$asset_path" | validate_archive_paths
      tar -xf "$asset_path" -C "$destination"
      ;;
    *.zip)
      if ! command_exists unzip; then
        echo "Cannot extract '${asset_name}': unzip is not installed." >&2
        return 1
      fi
      unzip -Z1 "$asset_path" | validate_archive_paths
      unzip -q "$asset_path" -d "$destination"
      ;;
    *.gz)
      output_name="${safe_name%.gz}"
      gzip -dc "$asset_path" >"${destination}/${output_name}"
      ;;
    *.xz)
      output_name="${safe_name%.xz}"
      xz -dc "$asset_path" >"${destination}/${output_name}"
      ;;
    *.bz2)
      output_name="${safe_name%.bz2}"
      bzip2 -dc "$asset_path" >"${destination}/${output_name}"
      ;;
    *.zst)
      output_name="${safe_name%.zst}"
      zstd -qdc "$asset_path" >"${destination}/${output_name}"
      ;;
    *)
      cp "$asset_path" "${destination}/${safe_name}"
      ;;
  esac
}

# Score a file found inside an asset. Exact command/repository names win, but
# executable type, bin directories, platform path components, and depth allow
# a differently named binary to be selected intelligently.
score_executable_candidate() {
  local path="$1" relative="$2" tool="$3" repo_name="$4" os="$5" arch="$6"
  local basename lower stem tokens description alias score=0 depth
  local runnable=0
  local desired_os desired_arch

  basename="${path##*/}"
  lower="$(tr '[:upper:]' '[:lower:]' <<<"$basename")"
  stem="${lower%.exe}"
  tokens="$(release_name_tokens "$relative")"
  description="$(file -b "$path" 2>/dev/null || true)"

  case "$os:$description" in
    linux:*Mach-O*|linux:*PE32*|macos:*ELF*|macos:*PE32*)
      echo -10000
      return
      ;;
  esac

  case "$lower" in
    readme*|license*|licence*|changelog*|changes*|notice*|copying*|*.md|*.txt|*.json|*.yaml|*.yml|*.toml|*.xml|*.html|*.1|*.man|*.sig|*.asc|*.pem|*.minisig|*.sha256|*.sha512|*.sum|*.so|*.so.*|*.dylib|*.dll|*.a|*.o|*.h|*.hpp|*.c|*.cc|*.cpp|*.go|*.rs)
      echo -10000
      return
      ;;
  esac

  if [ "$stem" = "$(tr '[:upper:]' '[:lower:]' <<<"$tool")" ]; then
    score=$((score + 220))
  elif tokens_contain "$tokens" "$(tr '[:upper:]' '[:lower:]' <<<"$tool")"; then
    score=$((score + 90))
  fi
  if [ "$stem" = "$(tr '[:upper:]' '[:lower:]' <<<"$repo_name")" ]; then
    score=$((score + 150))
  elif tokens_contain "$tokens" "$(tr '[:upper:]' '[:lower:]' <<<"$repo_name")"; then
    score=$((score + 60))
  fi

  [[ "/$relative" == */bin/* || "/$relative" == */sbin/* ]] && score=$((score + 45))
  if [ -x "$path" ]; then
    runnable=1
    score=$((score + 45))
  fi
  case "$description" in
    *script*) runnable=1; score=$((score + 45)) ;;
    *executable*) runnable=1; score=$((score + 70)) ;;
    *shared\ object*) score=$((score + 10)) ;;
  esac
  if [ "$runnable" -eq 0 ]; then
    echo -10000
    return
  fi

  read -r -a desired_os <<<"$(release_os_aliases "$os")"
  read -r -a desired_arch <<<"$(release_arch_aliases "$arch")"
  if tokens_match_any "$tokens" "${desired_os[@]}"; then
    score=$((score + 30))
  fi
  if tokens_match_any "$tokens" "${desired_arch[@]}"; then
    score=$((score + 25))
  fi
  for alias in linux darwin macos osx windows win32 win64 freebsd openbsd netbsd; do
    if tokens_contain "$tokens" "$alias" && ! value_in_list "$alias" "${desired_os[@]}"; then
      echo -10000
      return
    fi
  done
  for alias in amd64 x86_64 x64 386 i386 i686 arm64 aarch64 armv6 armv7 ppc64 ppc64le s390x; do
    if tokens_contain "$tokens" "$alias" && ! value_in_list "$alias" "${desired_arch[@]}"; then
      echo -10000
      return
    fi
  done

  depth="${relative//[^\/]/}"
  score=$((score - ${#depth}))
  echo "$score"
}

select_executable_candidate() {
  local root="$1" tool="$2" repo="$3" os="$4" arch="$5"
  local repo_name="${repo##*/}"
  local path relative score description
  local best_path="" best_score=-10001 tied=0 candidates=""

  while IFS= read -r -d '' path; do
    relative="${path#"$root"/}"
    score="$(score_executable_candidate "$path" "$relative" "$tool" "$repo_name" "$os" "$arch")"
    [ "$score" -gt -10000 ] || continue
    description="$(file -b "$path" 2>/dev/null || echo unknown)"
    candidates+="  score=${score}  ${relative}  (${description})"$'\n'
    if [ "$score" -gt "$best_score" ]; then
      best_score="$score"
      best_path="$path"
      tied=0
    elif [ "$score" -eq "$best_score" ]; then
      tied=1
    fi
  done < <(find "$root" -type f -print0)

  if [ -z "$best_path" ]; then
    echo "No executable candidate was found in the selected release asset." >&2
    return 1
  fi
  if [ "$tied" -eq 1 ]; then
    echo "Could not choose an unambiguous executable for '${tool}'." >&2
    printf '%s' "$candidates" >&2
    return 1
  fi

  if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
    echo "Selected executable '${best_path#"$root"/}' (score ${best_score})." >&2
  fi
  printf '%s\n' "$best_path"
}

# Function to install a tool from its GitHub release binaries into the tool cache
install_github_release_tool() {
  local tool="$1" repo="$2" requested_version="${3:-}"
  local os arch metadata version cache_version tool_path
  local selected_asset asset_name asset_id temp_dir download_path extract_path executable

  if [[ ! "$tool" =~ ^[A-Za-z0-9._+-]+$ ]] || [[ "$tool" == '.' || "$tool" == '..' ]]; then
    echo "Invalid command name for GitHub release installation: '${tool}'." >&2
    return 1
  fi

  os="$(tr '[:upper:]' '[:lower:]' <<<"$RUNNER_OS")"
  arch="$(determine_arch)"
  metadata="$(fetch_release_metadata "$repo" "$requested_version")"
  version="$(jq -r '.tag_name' <<<"$metadata")"
  cache_version="${version//\//_}"
  tool_path="${RUNNER_TOOL_CACHE}/${tool}/${cache_version}/${os}_${arch}"

  if [ ! -f "${tool_path}/${tool}" ]; then
    echo "${tool} not found in cache. Discovering a usable release binary from ${repo}@${version}..."
    selected_asset="$(select_release_asset "$metadata" "$tool" "$repo" "$os" "$arch")"
    IFS=$'\t' read -r asset_name asset_id <<<"$selected_asset"

    temp_dir="$(mktemp -d "${RUNNER_TEMP}/github-release-tool.XXXXXX")"
    download_path="${temp_dir}/download"
    extract_path="${temp_dir}/extracted"

    if ! gh api -H 'Accept: application/octet-stream' \
      "repos/${repo}/releases/assets/${asset_id}" >"$download_path"; then
      rm -rf "$temp_dir"
      echo "Failed to download release asset '${asset_name}' from ${repo}." >&2
      return 1
    fi
    if ! extract_release_asset "$download_path" "$asset_name" "$extract_path"; then
      rm -rf "$temp_dir"
      return 1
    fi
    if ! executable="$(select_executable_candidate "$extract_path" "$tool" "$repo" "$os" "$arch")"; then
      rm -rf "$temp_dir"
      return 1
    fi

    mkdir -p "$tool_path"
    install -m 0755 "$executable" "${tool_path}/${tool}"
    rm -rf "$temp_dir"
    echo "Installed '${asset_name}' as ${tool_path}/${tool}"
  else
    echo "${tool} found in cache at ${tool_path}"
  fi

  local version_var
  version_var="$(echo "$tool" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9_\n' '_')_VERSION"
  echo "${version_var}=${version}" >> "$GITHUB_ENV"

  append_toolpath "$tool_path"
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
  GITHUB_RELEASE_INSTALLS=()

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

    # Tools not available from system package managers are installed
    # from their GitHub releases instead, specified inline as
    # [command:]owner/repo[=version]
    local release_repo=""
    if [ "$pkg" = "actionlint" ]; then
      release_repo="rhysd/actionlint"
    elif [[ "$pkg" == */* ]]; then
      release_repo="$pkg"
      if [[ "$cmd" == */* ]]; then
        cmd="${pkg##*/}"
      fi
    fi

    # Skip if command exists
    if command_exists "$cmd"; then
      if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
        echo "Command '$cmd' found, skipping package installation"
      fi
      continue
    fi

    if [ -n "$release_repo" ]; then
      GITHUB_RELEASE_INSTALLS+=("${cmd}|${release_repo}|${version}")
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

install_github_release_dependencies() {
  if [ ${#GITHUB_RELEASE_INSTALLS[@]} -gt 0 ]; then
    echo "::group::Installing tools from GitHub releases"
    local release_entry release_tool release_repo release_version
    for release_entry in "${GITHUB_RELEASE_INSTALLS[@]}"; do
      IFS='|' read -r release_tool release_repo release_version <<< "$release_entry"
      if command_exists "$release_tool"; then
        if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
          echo "Command '$release_tool' is available; skipping release installation"
        fi
        continue
      fi
      install_github_release_tool "$release_tool" "$release_repo" "$release_version"
    done
    echo "::endgroup::"
  fi
}

# Function to fetch the latest version from GitHub API
fetch_latest_version() {
  fetch_release_metadata "$1" | jq -r '.tag_name'
}

fetch_bootstrap_gh_version() {
  curl -fsSL 'https://api.github.com/repos/cli/cli/releases/latest' \
    | jq -er '.tag_name | select(type == "string" and length > 0)'
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
  local gh_cli_path="${RUNNER_TOOL_CACHE}/gh-cli/${version}/${os}_${arch}"

  if [ ! -f "${gh_cli_path}/${gh_cli_binary}" ]; then
    echo "gh-cli not found in cache. Downloading and installing..."
    mkdir -p "${gh_cli_path}"
    local gh_cli_asset gh_cli_url gh_cli_temp download_path extract_path executable
    if [ "$os" = 'macos' ]; then
      gh_cli_asset="gh_${version#v}_macOS_${arch}.zip"
    else
      gh_cli_asset="gh_${version#v}_${os}_${arch}.tar.gz"
    fi
    gh_cli_temp="$(mktemp -d "${RUNNER_TEMP}/gh-cli-release.XXXXXX")"
    download_path="${gh_cli_temp}/download"
    extract_path="${gh_cli_temp}/extracted"
    gh_cli_url="https://github.com/cli/cli/releases/download/${version}/${gh_cli_asset}"
    if ! curl -fsSL "$gh_cli_url" -o "$download_path"; then
      rm -rf "$gh_cli_temp"
      return 1
    fi
    if ! extract_release_asset "$download_path" "$gh_cli_asset" "$extract_path"; then
      rm -rf "$gh_cli_temp"
      return 1
    fi
    if ! executable="$(select_executable_candidate "$extract_path" gh cli/cli "$os" "$arch")"; then
      rm -rf "$gh_cli_temp"
      return 1
    fi
    install -m 0755 "$executable" "${gh_cli_path}/${gh_cli_binary}"
    rm -rf "$gh_cli_temp"
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
    local asset_os="$os"
    [ "$asset_os" = 'macos' ] && asset_os='darwin'
    local yq_asset="yq_${asset_os}_${arch}"
    local yq_temp
    yq_temp="$(mktemp -d "${RUNNER_TEMP}/yq-release.XXXXXX")"
    if ! gh release download "$version" \
      --repo 'mikefarah/yq' \
      --pattern "$yq_asset" \
      --dir "$yq_temp"; then
      rm -rf "$yq_temp"
      return 1
    fi
    install -m 0755 "${yq_temp}/${yq_asset}" "${yq_path}/${yq_binary}"
    rm -rf "$yq_temp"
  else
    echo "yq found in cache at ${yq_path}"
  fi

  append_toolpath "${yq_path}"
}

# Function to update the PATH
update_path() {
  if [[ -n "$TOOLPATH" ]]; then
    tr ':' '\n' <<<"$TOOLPATH" >> "$GITHUB_PATH"
  fi
}

activate_toolpath() {
  if [[ -n "$TOOLPATH" ]]; then
    export PATH="${TOOLPATH}:${PATH}"
  fi
}

# Main Execution Flow
main() {
  echo '::group::Checking dependencies'

  # Base packages required for the action
  basePackages="curl jq wget file unzip gzip bzip2 zstd envsubst:gettext"
  if [[ "$RUNNER_OS" == 'Linux' ]] && command_exists apt-get; then
    basePackages+=" xz:xz-utils"
  else
    basePackages+=" xz"
  fi

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

  local gh_cli_version yq_version arch os gh_cli_path

  os="$(tr '[:upper:]' '[:lower:]' <<<"$RUNNER_OS")"  # 'linux' or 'macos'
  arch="$(determine_arch)"

  echo "::group::Setting up GitHub CLI"
  if command_exists gh; then
    gh_cli_path="$(command -v gh)"
    gh_cli_version="$(detect_existing_gh_version || true)"
    gh_cli_version="${gh_cli_version:-unknown}"
    echo "GitHub CLI found on PATH at ${gh_cli_path}"
    echo "Detected GitHub CLI version: $gh_cli_version"
  else
    echo "GitHub CLI not found on PATH. Fetching latest GitHub CLI version..."
    gh_cli_version="$(fetch_bootstrap_gh_version)"
    echo "Latest GitHub CLI version: $gh_cli_version"
    install_gh_cli "$gh_cli_version" "$os" "$arch"
    activate_toolpath
    command_exists gh || { echo "GitHub CLI installation did not provide the gh command." >&2; return 1; }
  fi
  echo "::endgroup::"

  echo "::group::Setting up yq YAML processor"
  echo "Fetching the latest yq version..."
  yq_version="$(fetch_latest_version 'mikefarah/yq')"
  echo "Latest yq version: $yq_version"
  install_yq "$yq_version" "$os" "$arch"
  activate_toolpath
  command_exists yq || { echo "yq installation did not provide the yq command." >&2; return 1; }
  echo "::endgroup::"

  # Record tool versions to GITHUB_ENV for later steps
  echo "GH_CLI_VERSION=$gh_cli_version" >> "$GITHUB_ENV"
  echo "YQ_VERSION=$yq_version" >> "$GITHUB_ENV"

  install_github_release_dependencies
  update_path

  echo '::endgroup::'
}

# Invoke main unless this file is sourced by its fixture tests.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
