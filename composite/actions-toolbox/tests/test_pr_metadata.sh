#!/usr/bin/env bash
set -euo pipefail

# Description: Fixture tests for the PR label and review-request extractors in
#              set_and_print_env.sh — the event-payload path, the gh-payload
#              fallback, and the precedence between them.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export GITHUB_ENV="${TEST_ROOT}/github-env"
export GITHUB_EVENT_PATH="${TEST_ROOT}/event.json"
touch "$GITHUB_ENV"

# shellcheck source=./composite/actions-toolbox/scripts/set_and_print_env.sh
source "${ACTION_DIR}/scripts/set_and_print_env.sh"

tests=0

pass() {
  tests=$((tests + 1))
  echo "ok ${tests} - $1"
}

fail() {
  echo "not ok - $1" >&2
  exit 1
}

assert_eq() {
  local expected="$1" actual="$2" message="$3"
  [[ "$actual" == "$expected" ]] || fail "${message}: expected '${expected}', got '${actual}'"
}

# --- Event payload: the common pull_request / pull_request_target path -------

cat > "$GITHUB_EVENT_PATH" <<'JSON'
{
  "pull_request": {
    "number": 42,
    "labels": [
      {"id": 1, "name": "documentation", "color": "0075ca"},
      {"id": 2, "name": "ci", "color": "ededed"}
    ],
    "requested_reviewers": [
      {"login": "wallentx", "id": 10},
      {"login": "jmhands", "id": 11}
    ],
    "requested_teams": [
      {"name": "Platform Team", "slug": "platform", "id": 20}
    ]
  }
}
JSON

meta="$(pr_metadata_from_event "$GITHUB_EVENT_PATH")"
assert_eq '["documentation","ci"]' "$(jq -c '.labels' <<<"$meta")" 'event labels'
assert_eq '["wallentx","jmhands"]' "$(jq -c '.reviewers' <<<"$meta")" 'event reviewers'
assert_eq '["platform"]' "$(jq -c '.teams' <<<"$meta")" 'event teams'
pass 'event payload yields labels, reviewers and teams'

# An opened PR with nothing set yet: every key present, all empty.
echo '{"pull_request": {"number": 43}}' > "$GITHUB_EVENT_PATH"
meta="$(pr_metadata_from_event "$GITHUB_EVENT_PATH")"
assert_eq '{"labels":[],"reviewers":[],"teams":[]}' "$meta" 'empty PR payload'
pass 'missing arrays become empty arrays, not null'

# --- Non-PR events: the extractor must decline, not emit empties -------------

echo '{"ref": "refs/heads/main", "commits": []}' > "$GITHUB_EVENT_PATH"
if pr_metadata_from_event "$GITHUB_EVENT_PATH" >/dev/null 2>&1; then
  fail 'push payload should not yield PR metadata'
fi
pass 'push payload declines'

if pr_metadata_from_event "${TEST_ROOT}/does-not-exist.json" >/dev/null 2>&1; then
  fail 'missing event file should not yield PR metadata'
fi
pass 'missing event file declines'

if pr_metadata_from_event '' >/dev/null 2>&1; then
  fail 'empty event path should not yield PR metadata'
fi
pass 'empty event path declines'

# --- gh payload fallback (merge_group, push, schedule) ----------------------
# The split of gh's single reviewRequests array back into users and teams.

gh_payload='{
  "number": 44,
  "labels": [{"name": "dependencies", "color": "0366d6"}],
  "reviewRequests": [
    {"__typename": "User", "login": "jmhands"},
    {"__typename": "Team", "name": "Platform Team", "slug": "platform"}
  ]
}'

meta="$(pr_metadata_from_payload <<<"$gh_payload")"
assert_eq '["dependencies"]' "$(jq -c '.labels' <<<"$meta")" 'gh labels'
assert_eq '["jmhands"]' "$(jq -c '.reviewers' <<<"$meta")" 'gh reviewers'
assert_eq '["platform"]' "$(jq -c '.teams' <<<"$meta")" 'gh teams'
pass 'gh payload splits users from teams'

# Teams are not guaranteed a slug, and a null would break downstream jq.
meta="$(pr_metadata_from_payload <<<'{"reviewRequests":[{"__typename":"Team","name":"Infra"}]}')"
assert_eq '["Infra"]' "$(jq -c '.teams' <<<"$meta")" 'team name fallback'
pass 'team without a slug falls back to its name'

meta="$(pr_metadata_from_payload <<<'{"number": 45}')"
assert_eq '{"labels":[],"reviewers":[],"teams":[]}' "$meta" 'gh payload without fields'
pass 'gh payload missing both fields yields empty arrays'

# --- Precedence: the event payload wins over the fetched payload ------------

cat > "$GITHUB_EVENT_PATH" <<'JSON'
{"pull_request": {"number": 46, "labels": [{"name": "from-event"}]}}
JSON
PR_PAYLOAD='{"labels":[{"name":"from-gh"}]}'

pr_meta="$(pr_metadata_from_event "$GITHUB_EVENT_PATH")" || pr_meta=""
if [[ -z "$pr_meta" ]]; then
  pr_meta="$(pr_metadata_from_payload <<<"$PR_PAYLOAD")" || pr_meta=""
fi
assert_eq '["from-event"]' "$(jq -c '.labels' <<<"$pr_meta")" 'event wins'
pass 'event payload takes precedence over the gh payload'

# ...and the fallback engages when the event has no pull_request object.
echo '{"merge_group": {"head_sha": "abc123"}}' > "$GITHUB_EVENT_PATH"
pr_meta="$(pr_metadata_from_event "$GITHUB_EVENT_PATH")" || pr_meta=""
if [[ -z "$pr_meta" ]]; then
  pr_meta="$(pr_metadata_from_payload <<<"$PR_PAYLOAD")" || pr_meta=""
fi
assert_eq '["from-gh"]' "$(jq -c '.labels' <<<"$pr_meta")" 'gh fallback'
pass 'merge_group falls back to the fetched payload'

# --- Values survive the trip through GITHUB_ENV -----------------------------
# Label names may contain spaces, colons and quotes; sEnvRaw must not mangle
# them and must not run them through envsubst.

: > "$GITHUB_ENV"
# shellcheck disable=SC2016 # $NOT_A_VAR must stay literal — that is the assertion
sEnvRaw GH_PR_LABELS '["needs: triage","$NOT_A_VAR","with \"quotes\""]' >/dev/null
# shellcheck disable=SC2016 # ditto: comparing against the unexpanded literal
assert_eq '["needs: triage","$NOT_A_VAR","with \"quotes\""]' \
  "$(sed -n 's/^GH_PR_LABELS=//p' "$GITHUB_ENV")" 'label round-trip'
pass 'awkward label names survive GITHUB_ENV verbatim'

echo "1..${tests}"
echo 'PASS: pr metadata extractors'
