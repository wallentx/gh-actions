#!/usr/bin/env bash
set -euo pipefail

# Description: This script checks for the existence of various context environment variables and then dumps the collected context variables to the log output as a YAML structure.

# Initialize an empty array for contexts
CONTEXTS=()


# Check for each context environment variable and add to the array if it exists
[ -n "${GITHUB_CONTEXT:-}" ] && CONTEXTS+=("GITHUB")
[ -n "${ENV_CONTEXT:-}" ] && CONTEXTS+=("ENV")
[ -n "${VARS_CONTEXT:-}" ] && CONTEXTS+=("VARS")
[ -n "${JOB_CONTEXT:-}" ] && CONTEXTS+=("JOB")
[ -n "${JOBS_CONTEXT:-}" ] && CONTEXTS+=("JOBS")
[ -n "${STEPS_CONTEXT:-}" ] && CONTEXTS+=("STEPS")
[ -n "${RUNNER_CONTEXT:-}" ] && CONTEXTS+=("RUNNER")
[ -n "${SECRETS_CONTEXT:-}" ] && CONTEXTS+=("SECRETS")
[ -n "${STRATEGY_CONTEXT:-}" ] && CONTEXTS+=("STRATEGY")
[ -n "${MATRIX_CONTEXT:-}" ] && CONTEXTS+=("MATRIX")
[ -n "${NEEDS_CONTEXT:-}" ] && CONTEXTS+=("NEEDS")
[ -n "${INPUTS_CONTEXT:-}" ] && CONTEXTS+=("INPUTS")

echo "――――――――――――――――――――――--"
echo "Dumping contexts:"
echo "――――――――――――――――――――――--"

dump_contexts() {
  for context in "${CONTEXTS[@]}"; do
    TEMP_CONTEXT="$(mktemp /tmp/context.XXXXXX)"
    DUMP="${context}_CONTEXT"
    echo "${!DUMP}" | yq -pj -oy > "${TEMP_CONTEXT}"
    yq -C -P "{\"${context}\": .}" "${TEMP_CONTEXT}"
    rm -f "${TEMP_CONTEXT}"
  done
}

dump_contexts

echo "――――――――――――――――――――――--"
