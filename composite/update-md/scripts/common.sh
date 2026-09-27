#!/usr/bin/env bash
set -euo pipefail
# Description: Shared Bash helpers for the generator and fixtures. Callers pass
# validated JSON on stdin and associative array names; input text is never eval'd.

json_object() {
  local -n object="$1"
  local -a pairs=()
  local i
  mapfile -d '' -t pairs < <(jq -j 'to_entries[] | .key, "\u0000", (.value | tostring), "\u0000"')
  # Nameref assignments populate the caller's array.
  # shellcheck disable=SC2034
  for ((i=0; i<${#pairs[@]}; i+=2)); do object["${pairs[i]}"]="${pairs[i+1]}"; done
}

render_template() {
  local text="$1" result='' token key
  local -n record="$2"
  [[ -n "$text" ]] || return 0
  while [[ "$text" =~ \{([a-z][a-z-]*)\} ]]; do
    token="${BASH_REMATCH[0]}" key="${BASH_REMATCH[1]}"
    [[ ${record[$key]+present} ]] || fail "Unknown template placeholder: $token"
    result+="${text%%"$token"*}${record[$key]}"
    text="${text#*"$token"}"
  done
  printf '%s\n' "$result$text"
}
