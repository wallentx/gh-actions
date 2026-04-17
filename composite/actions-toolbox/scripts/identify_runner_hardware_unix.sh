#!/usr/bin/env bash
set -euo pipefail

# Description: This script retrieves and writes the CPU model, number of cores, threads, and total memory of the system environment to GitHub environment variables. If verbose output is enabled, it provides extensive system information.

# Function to set and print environment variables
sEnv() {
  local var_name="$1"
  shift
  local raw_input=("$@")
  local var_value
  var_value="$(echo "${raw_input[*]}" | envsubst)"
  export "${var_name}=${var_value}" || {
    export "${var_name}="
    echo "${var_name}=" >>"$GITHUB_ENV"
    echo "Failed to set ${var_name}. Setting it to empty."
    return
  }
  echo "${var_name}=${var_value}" >>"$GITHUB_ENV"
  case "$var_name" in
    IID_* | AZURE_* | GCP_*)
      if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
        echo "${var_name}=${var_value}"
      else
        echo "${var_name}=<redacted>"
      fi
      ;;
    *)
      echo "${var_name}=${var_value}"
      ;;
  esac
  if [[ "${!var_name}" != "$var_value" ]]; then
    export "${var_name}="
    echo "${var_name}=" >>"$GITHUB_ENV"
    echo "Failed to set ${var_name}. Setting it to empty."
  fi
}

# Global Variables
RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
RUNNER_TOOL_CACHE="${RUNNER_TOOL_CACHE:-/opt/hostedtoolcache}"
GITHUB_ENV="${GITHUB_ENV:-}"

# Enable verbose output if RUNNER_VERBOSE is set
if [[ ${RUNNER_DEBUG:-0} -eq 1 ]]; then
  set -x
fi

# Error Handler
error_handler() {
  echo "An error occurred in ${BASH_SOURCE[0]} at line $1. Exiting gracefully." >&2
  exit 1
}
trap 'error_handler $LINENO' ERR

# Function to identify hardware on Linux
identify_hardware_linux() {
  export -f sEnv
  sEnv CPU_MODEL "$(lscpu | grep '^Model name:' | awk -F: '{print $2}' | xargs)" || sEnv CPU_MODEL ""
  sEnv CPU_CORES "$(lscpu | awk '/Core\(s\) per socket/ {print $4}')" || sEnv CPU_CORES ""
  sEnv CPU_THREADS "$(lscpu | awk '/^CPU\(s\):/ {print $2}')" || sEnv CPU_THREADS ""
  sEnv MEM_TOTAL "$(grep 'MemTotal' /proc/meminfo | awk '{print $2/1024/1024 "GB"}')" || sEnv MEM_TOTAL ""

  if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
    echo "――――――――――――――――――――――"
    echo "Set CPU_MODEL=$CPU_MODEL"
    echo "Set CPU_CORES=$CPU_CORES"
    echo "Set CPU_THREADS=$CPU_THREADS"
    echo "Set MEM_TOTAL=$MEM_TOTAL"
    echo "――――――――――――――――――――――"

    # Detailed CPU Information
    CPU_INFO=$(lscpu -J | jq '
      {
        lscpu: [
          {
            field: "Architecture",
            data: (.lscpu[] | select(.field == "Architecture:") | .data),
            children: [
              (.lscpu[] | select(.field == "CPU op-mode(s):")),
              (.lscpu[] | select(.field == "Address sizes:")),
              (.lscpu[] | select(.field == "Byte Order:"))
            ] | map(select(.field != null))
          },
          {
            field: "CPU(s)",
            data: (.lscpu[] | select(.field == "CPU(s):") | .data),
            children: [
              (.lscpu[] | select(.field == "On-line CPU(s) list:")),
              (.lscpu[] | select(.field == "Thread(s) per core:")),
              (.lscpu[] | select(.field == "Core(s) per socket:")),
              (.lscpu[] | select(.field == "Socket(s):"))
            ] | map(select(.field != null))
          },
          {
            field: "Vendor ID",
            data: (.lscpu[] | select(.field == "Vendor ID:") | .data),
            children: [
              {
                field: "Model name",
                data: (.lscpu[] | select(.field == "Model name:") | .data),
                children: [
                  (.lscpu[] | select(.field == "CPU family:")),
                  (.lscpu[] | select(.field == "Model:")),
                  (.lscpu[] | select(.field == "Stepping:")),
                  (.lscpu[] | select(.field == "CPU MHz:")),
                  (.lscpu[] | select(.field == "BogoMIPS:")),
                  (.lscpu[] | select(.field == "Flags:"))
                ] | map(select(.field != null))
              }
            ] | map(select(.field != null))
          },
          {
            field: "Virtualization features",
            data: null,
            children: [
              (.lscpu[] | select(.field == "Virtualization:")),
              (.lscpu[] | select(.field == "Hypervisor vendor:")),
              (.lscpu[] | select(.field == "Virtualization type:"))
            ] | map(select(.field != null))
          },
          {
            field: "Caches (sum of all)",
            data: null,
            children: [
              (.lscpu[] | select(.field | test("^L1d")) | .field = "L1d"),
              (.lscpu[] | select(.field | test("^L1i")) | .field = "L1i"),
              (.lscpu[] | select(.field | test("^L2")) | .field = "L2"),
              (.lscpu[] | select(.field | test("^L3")) | .field = "L3")
            ] | map(select(.field != null))
          },
          {
            field: "NUMA",
            data: null,
            children: [
              (.lscpu[] | select(.field == "NUMA node(s):")),
              (.lscpu[] | select(.field | test("^NUMA node[0-9] CPU")) | .field = "NUMA node CPU(s):")
            ] | map(select(.field != null))
          },
          {
            field: "Vulnerabilities",
            data: null,
            children: [
              (.lscpu[] | select(.field | test("^Vulnerability ")))
            ] | map(select(.field != null))
          }
        ]
      }
    ')

    CPU_YAML=$(echo "$CPU_INFO" | yq -P '.')
    FLAGS=$(lscpu -J | yq '.lscpu[] | select(.field == "Flags:") | .data | split(" ") | sort | unique | {"flags": .}')

    # Additional Info Processing (Optional)
    # Add any additional processing as needed

    # Combine CPU Info and Flags
    echo "――――――――――――――――――――――"
    echo "$CPU_YAML"
    echo "――――――――――――――――――――――"
    echo "$FLAGS"
    echo "――――――――――――――――――――――"
  fi
}

# Function to identify hardware on macOS
identify_hardware_macos() {
  export -f sEnv
  sEnv CPU_MODEL "$(sysctl -n machdep.cpu.brand_string)" || sEnv CPU_MODEL ""
  sEnv CPU_CORES "$(sysctl -n hw.physicalcpu)" || sEnv CPU_CORES ""
  sEnv CPU_THREADS "$(sysctl -n hw.logicalcpu)" || sEnv CPU_THREADS ""
  sEnv MEM_TOTAL "$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 "GB"}')" || sEnv MEM_TOTAL ""

  if [[ ${RUNNER_VERBOSE:-0} -eq 1 ]]; then
    echo "――――――――――――――――――――――"
    echo "Set CPU_MODEL=$CPU_MODEL"
    echo "Set CPU_CORES=$CPU_CORES"
    echo "Set CPU_THREADS=$CPU_THREADS"
    echo "Set MEM_TOTAL=$MEM_TOTAL"
    echo "――――――――――――――――――――――"

    # Detailed System Information
    sEnv SYSCTL_INFO "$(sysctl -a | sort | yq -P '{sysctl: .}')" || sEnv SYSCTL_INFO ""
    echo "$SYSCTL_INFO"
  fi
}

# Function to identify runner hardware based on OS
identify_runner_hardware() {
  if [[ "$OS_TYPE" == "linux" ]]; then
    identify_hardware_linux
  elif [[ "$OS_TYPE" == "macos" ]]; then
    identify_hardware_macos
  else
    echo "Unsupported OS type: $OS_TYPE" >&2
    exit 1
  fi
}

# Function to identify instance details
identify_instance_details() {
  export -f sEnv
  local AZURE_IMDS_API_VERSION="2025-04-07"

  # -----------------------------
  # Helpers
  # -----------------------------
  detect_cloud() {
    # prints: aws|azure|gcp|unknown

    # GitHub-hosted runners run on Azure, so avoid probing other metadata
    # services when GitHub has already identified the runner environment.
    if [[ "${RUNNER_ENVIRONMENT:-}" == "github-hosted" ]]; then
      echo "azure"
      return 0
    fi

    # --- AWS (EC2 IMDSv2) ---
    local token=""
    token="$(curl -fsS --connect-timeout 1 --max-time 2 \
      --noproxy "*" \
      -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 60" \
      2>/dev/null || true)"

    if [[ -n "$token" ]]; then
      local doc=""
      doc="$(curl -fsS --connect-timeout 1 --max-time 2 \
        --noproxy "*" \
        -H "X-aws-ec2-metadata-token: $token" \
        "http://169.254.169.254/latest/dynamic/instance-identity/document" \
        2>/dev/null || true)"

      if [[ -n "$doc" ]] && echo "$doc" | jq -e '.instanceId and .region' >/dev/null 2>&1; then
        echo "aws"
        return 0
      fi
    fi

    # --- Azure ---
    local az=""
    az="$(curl -fsS --connect-timeout 1 --max-time 2 \
      --noproxy "*" \
      -H "Metadata:true" \
      "http://169.254.169.254/metadata/instance?api-version=${AZURE_IMDS_API_VERSION}" \
      2>/dev/null || true)"

    if [[ -n "$az" ]] && echo "$az" | jq -e '.compute and .compute.vmId' >/dev/null 2>&1; then
      echo "azure"
      return 0
    fi

    # --- GCP ---
    # GCP returns the Metadata-Flavor response header when queried correctly.
    local gcp_headers=""
    gcp_headers="$(curl -sS -D - --connect-timeout 1 --max-time 2 \
      --noproxy "*" \
      -H "Metadata-Flavor: Google" \
      "http://169.254.169.254/computeMetadata/v1/instance/id" \
      -o /dev/null 2>/dev/null || true)"

    if echo "$gcp_headers" | grep -qi '^Metadata-Flavor: Google'; then
      echo "gcp"
      return 0
    fi

    echo "unknown"
  }

  export_json_vars() {
    local json="$1"
    local filter="$2"
    local details=""

    details="$(echo "$json" | jq -r "$filter | to_entries[] | select(.value != null) | \"\(.key)=\(.value)\"" 2>/dev/null || true)"
    if [[ -z "$details" ]]; then
      return 1
    fi

    while IFS='=' read -r name value; do
      [[ -z "${name:-}" ]] && continue
      sEnv "$name" "$value" || true
    done < <(echo "$details")
  }

  identify_aws_instance_details() {
    local TOKEN=""
    TOKEN="$(curl -fsS --connect-timeout 1 --max-time 2 \
      --noproxy "*" \
      -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
      2>/dev/null || true)"

    if [[ -z "$TOKEN" ]]; then
      echo "AWS IMDS token fetch failed/empty; skipping instance detection."
      return 0
    fi

    local INSTANCE_JSON=""
    INSTANCE_JSON="$(curl -fsS --connect-timeout 1 --max-time 2 \
      --noproxy "*" \
      -H "X-aws-ec2-metadata-token: $TOKEN" \
      "http://169.254.169.254/latest/dynamic/instance-identity/document" \
      2>/dev/null || true)"

    if [[ -z "$INSTANCE_JSON" ]]; then
      echo "AWS IMDS instance identity document empty; skipping."
      return 0
    fi

    # Validate JSON before yq -pj (prevents: invalid character '<' ...)
    if ! echo "$INSTANCE_JSON" | jq -e . >/dev/null 2>&1; then
      echo "AWS IMDS response was not valid JSON; skipping. (First bytes: $(echo "$INSTANCE_JSON" | head -c 20 | tr '\n' ' '))"
      return 0
    fi

    local INSTANCE_YQ=""
    INSTANCE_YQ="$(yq -pj -os '
      sort_keys(.)
      | with_entries(
          .key |= ("IID_" + (. | upcase))
          | .value |= (. // "")
        )
    ' <<< "$INSTANCE_JSON" 2>/dev/null || true)"

    if [[ -z "$INSTANCE_YQ" ]]; then
      echo "yq failed to parse/transform AWS IMDS JSON; skipping."
      return 0
    fi

    # Remove single quotes from the output, then set IID_* vars
    local INSTANCE_DETAILS=""
    INSTANCE_DETAILS="${INSTANCE_YQ//\'/}"

    while IFS='=' read -r name value; do
      [[ -z "${name:-}" ]] && continue
      sEnv "$name" "$value" || true
    done < <(echo "$INSTANCE_DETAILS")
  }

  identify_azure_instance_details() {
    local INSTANCE_JSON=""
    INSTANCE_JSON="$(curl -fsS --connect-timeout 1 --max-time 2 \
      --noproxy "*" \
      -H "Metadata:true" \
      "http://169.254.169.254/metadata/instance?api-version=${AZURE_IMDS_API_VERSION}" \
      2>/dev/null || true)"

    if [[ -z "$INSTANCE_JSON" ]]; then
      echo "Azure IMDS instance document empty; skipping."
      return 0
    fi

    if ! echo "$INSTANCE_JSON" | jq -e '.compute' >/dev/null 2>&1; then
      echo "Azure IMDS response was not valid JSON; skipping. (First bytes: $(echo "$INSTANCE_JSON" | head -c 20 | tr '\n' ' '))"
      return 0
    fi

    export_json_vars "$INSTANCE_JSON" '
      .compute
      | {
          AZURE_AZ_ENVIRONMENT: .azEnvironment,
          AZURE_LOCATION: .location,
          AZURE_NAME: .name,
          AZURE_OS_TYPE: .osType,
          AZURE_PLATFORM_FAULT_DOMAIN: .platformFaultDomain,
          AZURE_PLATFORM_UPDATE_DOMAIN: .platformUpdateDomain,
          AZURE_RESOURCE_GROUP_NAME: .resourceGroupName,
          AZURE_RESOURCE_ID: .resourceId,
          AZURE_SUBSCRIPTION_ID: .subscriptionId,
          AZURE_VM_ID: .vmId,
          AZURE_VM_SIZE: .vmSize,
          AZURE_ZONE: .zone
        }
    ' || echo "Azure IMDS JSON had no recognized properties to export; skipping."
  }

  identify_gcp_instance_details() {
    local INSTANCE_JSON=""
    INSTANCE_JSON="$(curl -fsS --connect-timeout 1 --max-time 2 \
      --noproxy "*" \
      -H "Metadata-Flavor: Google" \
      "http://metadata.google.internal/computeMetadata/v1/instance/?recursive=true" \
      2>/dev/null || true)"

    if [[ -z "$INSTANCE_JSON" ]]; then
      echo "GCP metadata instance document empty; skipping."
      return 0
    fi

    if ! echo "$INSTANCE_JSON" | jq -e . >/dev/null 2>&1; then
      echo "GCP metadata response was not valid JSON; skipping. (First bytes: $(echo "$INSTANCE_JSON" | head -c 20 | tr '\n' ' '))"
      return 0
    fi

    export_json_vars "$INSTANCE_JSON" '
      {
        GCP_HOSTNAME: .hostname,
        GCP_ID: .id,
        GCP_MACHINE_TYPE: .machineType,
        GCP_NAME: .name,
        GCP_ZONE: .zone
      }
    ' || echo "GCP metadata JSON had no recognized properties to export; skipping."
  }

  # -----------------------------
  # Auto-detect cloud, then act
  # -----------------------------
  local CLOUD_PROVIDER="unknown"
  CLOUD_PROVIDER="$(detect_cloud || echo unknown)"

  # Always export provider for visibility (optional, but useful)
  sEnv CLOUD_PROVIDER "$CLOUD_PROVIDER" || true

  case "$CLOUD_PROVIDER" in
    aws)
      identify_aws_instance_details
      ;;
    azure)
      identify_azure_instance_details
      ;;
    gcp)
      identify_gcp_instance_details
      ;;
    *)
      echo "Cloud provider unknown; skipping instance metadata query."
      ;;
  esac
}

# Main Execution Flow
main() {
  echo '::group::Identifying Runner Hardware'
  if [[ "$RUNNER_OS" == "Linux" ]]; then
    OS_TYPE="linux"
  elif [[ "$RUNNER_OS" == "macOS" ]]; then
    OS_TYPE="macos"
  else
    echo "Unsupported OS: $RUNNER_OS" >&2
    exit 1
  fi

  identify_runner_hardware
  echo '::endgroup::'

  echo '::group::Identifying Instance Details'
  identify_instance_details
  echo '::endgroup::'
}

# Invoke main
main
