#!/usr/bin/env bash
set -euo pipefail

# Description: Verifies issue_comment PR discovery, changed files, branch
# metadata, and comment-body exports from set_and_print_env.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export GITHUB_ENV="${TEST_ROOT}/github-env"
export GITHUB_EVENT_PATH="${TEST_ROOT}/event.json"
export GITHUB_REPOSITORY='FarmGPU/example'
export GITHUB_SHA='default-branch-sha'
export GH_CALL_LOG="${TEST_ROOT}/gh-calls"
export GH_PR_FIXTURE="${TEST_ROOT}/pr.json"

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

assert_call() {
  local expected="$1" message="$2"
  grep -qF -- "$expected" "$GH_CALL_LOG" || fail "${message}: missing '${expected}'"
}

reject_call() {
  local unwanted="$1" message="$2"
  if grep -qF -- "$unwanted" "$GH_CALL_LOG"; then
    fail "${message}: found '${unwanted}'"
  fi
}

env_value() {
  local name="$1"
  sed -n "s/^${name}=//p" "$GITHUB_ENV"
}

reject_env() {
  local name="$1" message="$2"
  if grep -q "^${name}=" "$GITHUB_ENV"; then
    fail "$message"
  fi
}

gh() {
  printf '%s\n' "$*" >> "$GH_CALL_LOG"
  if [[ "$1" == 'pr' && "$2" == 'view' ]]; then
    [[ "${GH_PR_VIEW_FAIL:-false}" != 'true' ]] || return 1
    cat "$GH_PR_FIXTURE"
  elif [[ "$1" == 'pr' && "$2" == 'list' ]]; then
    jq 'del(.reviews, .comments, .reviewDecision)' "$GH_PR_FIXTURE"
  elif [[ "$1" == 'api' ]]; then
    printf '%s\n' '[[{"filename":"src/add.sh","status":"added"},{"filename":"src/remove.sh","status":"removed"}]]'
  else
    return 1
  fi
}

cat > "$GH_PR_FIXTURE" <<'JSON'
{
  "number": 77,
  "title": "Handle issue comments",
  "body": "PR body",
  "url": "https://github.com/FarmGPU/example/pull/77",
  "state": "OPEN",
  "isDraft": false,
  "author": {"login": "contributor"},
  "headRefName": "feature/comment-event",
  "headRefOid": "head-sha",
  "baseRefName": "main",
  "baseRefOid": "base-sha",
  "createdAt": "2026-09-15T12:00:00Z",
  "mergedAt": null,
  "updatedAt": "2026-09-16T12:00:00Z",
  "reviews": [],
  "comments": [
    {
      "author": {"login": "reviewer"},
      "url": "https://github.com/FarmGPU/example/pull/77#issuecomment-1",
      "body": "placeholder"
    }
  ],
  "reviewDecision": "REVIEW_REQUIRED",
  "labels": [{"name": "automation"}],
  "reviewRequests": [{"login": "reviewer"}]
}
JSON

long_pr_comment="/push-docs $(printf '🧪%.0s' {1..250})"
jq --arg body "$long_pr_comment" '
  .comments = [
    range(0; 21) as $index
    | {
        author: {login: "reviewer"},
        url: "https://github.com/FarmGPU/example/pull/77#issuecomment-\($index)",
        body: (if $index == 20 then $body else "comment \($index)" end)
      }
  ]
' "$GH_PR_FIXTURE" > "${GH_PR_FIXTURE}.tmp"
mv "${GH_PR_FIXTURE}.tmp" "$GH_PR_FIXTURE"

cat > "$GITHUB_EVENT_PATH" <<'JSON'
{
  "issue": {
    "number": 77,
    "pull_request": {"url": "https://api.github.com/repos/FarmGPU/example/pulls/77"}
  },
  "comment": {
    "body": "placeholder",
    "html_url": "https://github.com/FarmGPU/example/pull/77#issuecomment-1"
  }
}
JSON

long_event_comment="/pull-docs $(printf '🧪%.0s' {1..250})"
jq --arg body "$long_event_comment" '.comment.body = $body' "$GITHUB_EVENT_PATH" > "${GITHUB_EVENT_PATH}.tmp"
mv "${GITHUB_EVENT_PATH}.tmp" "$GITHUB_EVENT_PATH"

: > "$GITHUB_ENV"
: > "$GH_CALL_LOG"
export GITHUB_EVENT_NAME='issue_comment'
set_changed_files_env >/dev/null
set_pr_env >/dev/null

assert_call 'pr view 77 ' 'PR issue comment resolves by issue number'
reject_call 'pr list' 'PR issue comment does not use merged-SHA lookup'
assert_call '/pulls/77/files?per_page=100' 'changed files use the commented PR'
assert_call 'headRefName,headRefOid,baseRefName,baseRefOid' \
  'PR lookup requests head and base metadata'
assert_eq '["src/add.sh"]' "$(env_value FILES_CHANGED)" 'changed files'
assert_eq '["src/remove.sh"]' "$(env_value FILES_DELETED)" 'deleted files'
assert_eq '77' "$(env_value GH_PR)" 'PR number'
assert_eq 'feature/comment-event' "$(env_value GH_PR_HEAD_REF)" 'head ref'
assert_eq 'head-sha' "$(env_value GH_PR_HEAD_SHA)" 'head SHA'
assert_eq 'main' "$(env_value GH_PR_BASE_REF)" 'base ref'
assert_eq 'base-sha' "$(env_value GH_PR_BASE_SHA)" 'base SHA'
comments="$(env_value GH_PR_COMMENTS)"
assert_eq '20' "$(jq -r 'length' <<<"$comments")" 'PR comment count'
assert_eq 'comment 1' "$(jq -r '.[0].body' <<<"$comments")" 'oldest omitted PR comment'
assert_eq '200' "$(jq -r '.[-1].body | length' <<<"$comments")" 'PR comment body limit'
assert_eq 'true' "$(jq -r '.[-1].body | startswith("/push-docs")' <<<"$comments")" \
  'PR comment trigger prefix'
assert_eq 'true' "$(env_value GH_PR_COMMENTS_TRUNCATED)" 'PR comment truncation indicator'
assert_eq '200' "$(jq -r 'length' <<<"$(env_value GH_EVENT_COMMENT_BODY_JSON)")" \
  'triggering comment body limit'
assert_eq 'true' "$(jq -r 'startswith("/pull-docs")' <<<"$(env_value GH_EVENT_COMMENT_BODY_JSON)")" \
  'triggering comment prefix'
assert_eq 'true' "$(env_value GH_EVENT_COMMENT_BODY_TRUNCATED)" \
  'triggering comment truncation indicator'
GH_PR_COMMENTS="$comments" \
  GH_EVENT_COMMENT_BODY_JSON="$(env_value GH_EVENT_COMMENT_BODY_JSON)" \
  /usr/bin/true || fail 'bounded comment metadata could not launch a subprocess'
pass 'PR issue comments export bounded visual summaries'

cat > "$GITHUB_EVENT_PATH" <<'JSON'
{
  "issue": {"number": 88},
  "comment": {"body": "ordinary issue comment"}
}
JSON

: > "$GITHUB_ENV"
: > "$GH_CALL_LOG"
set_changed_files_env >/dev/null
set_pr_env >/dev/null

[[ ! -s "$GH_CALL_LOG" ]] || fail 'ordinary issue comment made a GitHub API call'
assert_eq '[]' "$(env_value FILES_CHANGED)" 'ordinary issue changed files'
assert_eq '[]' "$(env_value FILES_DELETED)" 'ordinary issue deleted files'
assert_eq '"ordinary issue comment"' "$(env_value GH_EVENT_COMMENT_BODY_JSON)" \
  'ordinary issue triggering comment body'
assert_eq 'false' "$(env_value GH_EVENT_COMMENT_BODY_TRUNCATED)" \
  'ordinary issue comment is not truncated'
reject_env GH_PR 'ordinary issue comment exported PR metadata'
pass 'ordinary issue comments do not invent a PR context'

cat > "$GITHUB_EVENT_PATH" <<'JSON'
{
  "pull_request": {
    "number": 77,
    "head": {"ref": "feature/from-event", "sha": "event-head-sha"},
    "base": {"ref": "main", "sha": "event-base-sha"},
    "labels": [],
    "requested_reviewers": [],
    "requested_teams": []
  }
}
JSON

: > "$GITHUB_ENV"
: > "$GH_CALL_LOG"
export GITHUB_EVENT_NAME='pull_request'
export GH_PR_VIEW_FAIL='true'
set_pr_env >/dev/null 2>&1
unset GH_PR_VIEW_FAIL

assert_eq 'feature/from-event' "$(env_value GH_PR_HEAD_REF)" 'event head ref fallback'
assert_eq 'event-head-sha' "$(env_value GH_PR_HEAD_SHA)" 'event head SHA fallback'
assert_eq 'main' "$(env_value GH_PR_BASE_REF)" 'event base ref fallback'
assert_eq 'event-base-sha' "$(env_value GH_PR_BASE_SHA)" 'event base SHA fallback'
pass 'pull request refs survive a failed API lookup'

export GITHUB_EVENT_NAME='merge_group'
export GITHUB_REF_NAME='gh-readonly-queue/pr-9-legacy/pr-123-abcdef'
assert_eq '123' "$(event_pr_number)" 'merge queue uses final PR segment'
export GITHUB_REF_NAME='gh-readonly-queue/main/no-pr-segment'
assert_eq '' "$(event_pr_number)" 'merge queue rejects refs without a PR segment'
pass 'merge queue PR parsing is strict and preserves final-segment behavior'

cat > "$GITHUB_EVENT_PATH" <<'JSON'
{}
JSON

: > "$GITHUB_ENV"
: > "$GH_CALL_LOG"
export GITHUB_EVENT_NAME='push'
unset GITHUB_REF_NAME
set_pr_env >/dev/null

assert_call 'pr list ' 'push event uses the SHA fallback'
reject_call 'reviews,comments' 'SHA fallback omits unbounded review and comment fields'
assert_eq '[]' "$(env_value GH_PR_REVIEWS)" 'SHA fallback reviews remain empty'
assert_eq '[]' "$(env_value GH_PR_COMMENTS)" 'SHA fallback comments remain empty'
pass 'SHA fallback preserves its reduced metadata contract'

echo "1..${tests}"
echo 'PASS: issue_comment metadata'
