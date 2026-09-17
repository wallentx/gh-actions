#!/usr/bin/env bash
set -euo pipefail

# Description: Verifies Actions Toolbox metadata marker planning and action step gating.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_DIR="$(cd "${TEST_DIR}/.." && pwd)"
PLANNER="${ACTION_DIR}/scripts/plan_metadata_snapshot.sh"
ACTION_FILE="${ACTION_DIR}/action.yml"
TEMP_DIR=''

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_output() {
  local file="$1"
  local expected="$2"
  grep -Fxq "$expected" "$file" || fail "expected '${expected}' in ${file}"
}

run_plan() {
  local mode="$1"
  local checkout="$2"
  local marker="$3"
  local output_file="$4"
  local env_file="$5"

  : > "$output_file"
  : > "$env_file"
  INPUT_MARKER_MODE="$mode" \
    INPUT_CHECKOUT="$checkout" \
    ACTIONS_TOOLBOX_MARKER="$marker" \
    GITHUB_OUTPUT="$output_file" \
    GITHUB_ENV="$env_file" \
    bash "$PLANNER"
}

test_first_auto_writes_marker() {
  local output_file="$1"
  local env_file="$2"
  run_plan auto false '' "$output_file" "$env_file"
  assert_output "$output_file" 'run-snapshot=true'
  assert_output "$output_file" 'write-marker=true'
  GITHUB_ENV="$env_file" bash "$PLANNER" write-marker
  assert_output "$env_file" 'ACTIONS_TOOLBOX_MARKER=2'
}

test_matching_auto_skips_snapshot() {
  local output_file="$1"
  local env_file="$2"
  run_plan auto false 2 "$output_file" "$env_file"
  assert_output "$output_file" 'run-snapshot=false'
  assert_output "$output_file" 'write-marker=false'
  [[ ! -s "$env_file" ]] || fail 'matching auto marker modified GITHUB_ENV'
}

test_outdated_auto_regenerates() {
  local output_file="$1"
  local env_file="$2"
  run_plan auto false 1 "$output_file" "$env_file"
  assert_output "$output_file" 'run-snapshot=true'
  assert_output "$output_file" 'write-marker=true'
}

test_refresh_invalidates_and_replaces() {
  local output_file="$1"
  local env_file="$2"
  run_plan refresh false 2 "$output_file" "$env_file"
  assert_output "$output_file" 'run-snapshot=true'
  assert_output "$output_file" 'write-marker=true'
  assert_output "$env_file" 'ACTIONS_TOOLBOX_MARKER='
  GITHUB_ENV="$env_file" bash "$PLANNER" write-marker
  [[ "$(tail -n 1 "$env_file")" == 'ACTIONS_TOOLBOX_MARKER=2' ]] \
    || fail 'refresh did not replace the invalidated marker'
}

test_bypass_ignores_marker() {
  local output_file="$1"
  local env_file="$2"
  run_plan bypass false poison "$output_file" "$env_file"
  assert_output "$output_file" 'run-snapshot=true'
  assert_output "$output_file" 'write-marker=false'
  [[ ! -s "$env_file" ]] || fail 'bypass modified GITHUB_ENV'
}

test_invalid_mode_fails_before_writes() {
  local output_file="$1"
  local env_file="$2"
  local error_file="$3"
  : > "$output_file"
  : > "$env_file"
  if INPUT_MARKER_MODE=invalid INPUT_CHECKOUT=false ACTIONS_TOOLBOX_MARKER=2 \
    GITHUB_OUTPUT="$output_file" GITHUB_ENV="$env_file" \
    bash "$PLANNER" > "$error_file" 2>&1; then
    fail 'invalid marker mode succeeded'
  fi
  grep -Fq "::error::Invalid marker-mode 'invalid'" "$error_file" \
    || fail 'invalid marker mode did not emit a clear workflow error'
  [[ ! -s "$output_file" && ! -s "$env_file" ]] \
    || fail 'invalid marker mode wrote action state'
}

test_checkout_forces_regeneration() {
  local output_file="$1"
  local env_file="$2"
  run_plan auto true 2 "$output_file" "$env_file"
  assert_output "$output_file" 'run-snapshot=true'
  assert_output "$output_file" 'write-marker=true'
  assert_output "$env_file" 'ACTIONS_TOOLBOX_MARKER='
}

test_action_keeps_setup_outside_snapshot_gate() {
  local dependencies_block windows_dependencies_block
  dependencies_block="$(sed -n '/name: Check Dependencies (Linux\/MacOS)/,/name: Check Dependencies (Windows)/p' "$ACTION_FILE")"
  windows_dependencies_block="$(sed -n '/name: Check Dependencies (Windows)/,/name: Identify Runner Hardware (Linux\/MacOS)/p' "$ACTION_FILE")"
  grep -Fq "INPUT_INCLUDE_PACKAGES: \${{ inputs.include-packages }}" <<< "$dependencies_block" \
    || fail 'dependency setup no longer receives include-packages'
  grep -Fq "INPUT_INCLUDE_PACKAGES: \${{ inputs.include-packages }}" <<< "$windows_dependencies_block" \
    || fail 'Windows dependency setup does not receive include-packages'
  if grep -Fq 'metadata-plan.outputs.run-snapshot' <<< "$dependencies_block"; then
    fail 'dependency setup is incorrectly gated by snapshot reuse'
  fi
  if grep -Fq 'metadata-plan.outputs.run-snapshot' <<< "$windows_dependencies_block"; then
    fail 'Windows dependency setup is incorrectly gated by snapshot reuse'
  fi
  grep -Fq "if: steps.metadata-plan.outputs.run-snapshot == 'true'" "$ACTION_FILE" \
    || fail 'snapshot steps do not consume the central plan output'
}

main() {
  local output_file env_file error_file
  TEMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TEMP_DIR"' EXIT
  output_file="${TEMP_DIR}/output"
  env_file="${TEMP_DIR}/env"
  error_file="${TEMP_DIR}/error"

  test_first_auto_writes_marker "$output_file" "$env_file"
  test_matching_auto_skips_snapshot "$output_file" "$env_file"
  test_outdated_auto_regenerates "$output_file" "$env_file"
  test_refresh_invalidates_and_replaces "$output_file" "$env_file"
  test_bypass_ignores_marker "$output_file" "$env_file"
  test_invalid_mode_fails_before_writes "$output_file" "$env_file" "$error_file"
  test_checkout_forces_regeneration "$output_file" "$env_file"
  test_action_keeps_setup_outside_snapshot_gate
  echo 'PASS: metadata snapshot marker fixtures'
}

main
