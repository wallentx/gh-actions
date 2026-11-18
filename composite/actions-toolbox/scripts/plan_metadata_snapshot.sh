#!/usr/bin/env bash
set -euo pipefail

# Description: Plans metadata snapshot collection from marker-mode and checkout inputs, and writes the versioned job marker after a successful snapshot.

MARKER_VERSION='3'

worktree_signature() {
  local workspace="${GITHUB_WORKSPACE:-$PWD}"
  local root sha
  if root="$(git -C "$workspace" rev-parse --show-toplevel 2>/dev/null)" &&
    sha="$(git -C "$workspace" rev-parse HEAD 2>/dev/null)"; then
    printf '%s@%s\n' "$root" "$sha"
  else
    printf 'none\n'
  fi
}

write_output() {
  printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
}

invalidate_marker() {
  printf 'ACTIONS_TOOLBOX_MARKER=\n' >> "$GITHUB_ENV"
  printf 'ACTIONS_TOOLBOX_WORKTREE=\n' >> "$GITHUB_ENV"
}

write_marker() {
  printf 'ACTIONS_TOOLBOX_MARKER=%s\n' "$MARKER_VERSION" >> "$GITHUB_ENV"
  printf 'ACTIONS_TOOLBOX_WORKTREE=%s\n' "$(worktree_signature)" >> "$GITHUB_ENV"
  echo "Actions Toolbox metadata snapshot marker set to version ${MARKER_VERSION}."
}

plan_snapshot() {
  local mode="${INPUT_MARKER_MODE:-auto}"
  local checkout="${INPUT_CHECKOUT:-false}"
  local run_snapshot write_marker reason

  case "$mode" in
    auto | refresh | bypass) ;;
    *)
      echo "::error::Invalid marker-mode '${mode}'. Expected one of: auto, refresh, bypass."
      return 1
      ;;
  esac

  case "$mode" in
    bypass)
      run_snapshot='true'
      write_marker='false'
      reason='marker bypass requested'
      ;;
    refresh)
      invalidate_marker
      run_snapshot='true'
      write_marker='true'
      reason='snapshot refresh requested'
      ;;
    auto)
      if [[ "$checkout" == 'true' ]]; then
        invalidate_marker
        run_snapshot='true'
        write_marker='true'
        reason='checkout can change worktree metadata'
      elif [[ "${ACTIONS_TOOLBOX_MARKER:-}" == "$MARKER_VERSION" &&
        "${ACTIONS_TOOLBOX_WORKTREE:-}" == "$(worktree_signature)" ]]; then
        run_snapshot='false'
        write_marker='false'
        reason="metadata snapshot version ${MARKER_VERSION} already exists"
      else
        invalidate_marker
        run_snapshot='true'
        write_marker='true'
        reason='metadata snapshot marker or worktree is missing or changed'
      fi
      ;;
  esac

  write_output 'run-snapshot' "$run_snapshot"
  write_output 'write-marker' "$write_marker"
  write_output 'reason' "$reason"
  echo "Actions Toolbox metadata snapshot run=${run_snapshot}: ${reason}."
}

case "${1:-plan}" in
  plan)
    plan_snapshot
    ;;
  write-marker)
    write_marker
    ;;
  *)
    echo "::error::Unknown metadata snapshot planner command '$1'."
    exit 1
    ;;
esac
