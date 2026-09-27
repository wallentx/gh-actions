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
  local text="$1" result='' token key lookup value
  local -n record="$2"
  [[ -n "$text" ]] || return 0
  while [[ "$text" =~ \{([a-z][a-z-]*)\} ]]; do
    token="${BASH_REMATCH[0]}" key="${BASH_REMATCH[1]}"
    lookup="$key"; [[ "$key" != escaped-title ]] || lookup=title
    [[ ${record[$lookup]+present} ]] || fail "Unknown template placeholder: $token"
    value="${record[$lookup]}"
    if [[ "$key" == escaped-title ]]; then
      value="${value//\\/\\\\}"; value="${value//\[/\\[}"; value="${value//\]/\\]}"
    fi
    result+="${text%%"$token"*}$value"
    text="${text#*"$token"}"
  done
  printf '%s\n' "$result$text"
}
