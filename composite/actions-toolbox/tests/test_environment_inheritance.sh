#!/usr/bin/env bash
# shellcheck disable=SC2016 # The fixtures intentionally preserve literal dollar signs.
set -euo pipefail

# Description: These fixtures verify that metadata setup preserves inherited
# environment values and does not interpret their contents as assignments.

test_dir=${BASH_SOURCE[0]%/*}
[[ "$test_dir" != "${BASH_SOURCE[0]}" ]] || test_dir=.
script="${test_dir}/../scripts/set_and_print_env.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

export GITHUB_INHERITANCE_SINGLE=' spaces = $literal *?[glob] \ '
export GITHUB_INHERITANCE_MULTILINE=$'first\nsecond\n'
export INHERITANCE_OTHER=$'first\nGITHUB_INHERITANCE_SYNTHETIC=second'
unset GITHUB_INHERITANCE_SYNTHETIC GITHUB_INHERITANCE_LOCAL
GITHUB_INHERITANCE_LOCAL='local-only'

# shellcheck source=./composite/actions-toolbox/scripts/set_and_print_env.sh
source "$script"

[[ "$GITHUB_INHERITANCE_SINGLE" == ' spaces = $literal *?[glob] \ ' ]] \
  || fail 'metadata setup changed a single-line value'
[[ "$GITHUB_INHERITANCE_MULTILINE" == $'first\nsecond\n' ]] \
  || fail 'metadata setup changed a multiline value'
[[ ! -v GITHUB_INHERITANCE_SYNTHETIC ]] \
  || fail 'metadata setup interpreted another variable as an assignment'

observed=$(envsubst <<< '${GITHUB_INHERITANCE_SINGLE}END')
[[ "$observed" == "${GITHUB_INHERITANCE_SINGLE}END" ]] \
  || fail 'a child process did not inherit the single-line value'
observed=$(envsubst <<< '${GITHUB_INHERITANCE_MULTILINE}END')
[[ "$observed" == "${GITHUB_INHERITANCE_MULTILINE}END" ]] \
  || fail 'a child process did not inherit the complete multiline value'
[[ "$GITHUB_INHERITANCE_LOCAL" == 'local-only' ]] \
  || fail 'metadata setup changed an unexported shell variable'
bash -c '[[ ! -v GITHUB_INHERITANCE_LOCAL ]]' \
  || fail 'metadata setup exported a caller-local variable'

(
  export GITHUB_INHERITANCE_READONLY='unchanged'
  readonly GITHUB_INHERITANCE_READONLY
  # shellcheck source=./composite/actions-toolbox/scripts/set_and_print_env.sh
  source "$script"
  [[ "$GITHUB_INHERITANCE_READONLY" == 'unchanged' ]]
)

printf '%s\n' 'PASS: metadata environment inheritance'
