#!/usr/bin/env bash
set -euo pipefail

# Description: Verifies checkout-based commit metadata, snapshot invalidation,
#              and complete merge-group file sets, including shallow checkouts.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_DIR="$(cd "${TEST_DIR}/.." && pwd)"
PLANNER="${ACTION_DIR}/scripts/plan_metadata_snapshot.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export GITHUB_ENV="${TEST_ROOT}/env"
export GITHUB_EVENT_PATH="${TEST_ROOT}/event.json"
export GITHUB_OUTPUT="${TEST_ROOT}/output"
export GITHUB_REPOSITORY='FarmGPU/example'
export GITHUB_REPOSITORY_OWNER='FarmGPU'
export GITHUB_SERVER_URL='https://github.example.com'
export GITHUB_RUN_ID='fixture'
export GH_CALL_LOG="${TEST_ROOT}/gh-calls"
export GITHUB_WORKSPACE="${TEST_ROOT}/workspace"
mkdir -p "$GITHUB_WORKSPACE"
touch "$GITHUB_ENV" "$GITHUB_OUTPUT" "$GH_CALL_LOG"

# These commits exist only in the temporary fixture repository.
git -C "$GITHUB_WORKSPACE" init -q --initial-branch=wallentx/toolbox-fixture
git -C "$GITHUB_WORKSPACE" config user.name 'GitHub Actions'
git -C "$GITHUB_WORKSPACE" config user.email '41898282+github-actions[bot]@users.noreply.github.com'
printf 'original a\n' > "$GITHUB_WORKSPACE/service_a.txt"
printf 'original b\n' > "$GITHUB_WORKSPACE/service_b.txt"
printf 'remove a\n' > "$GITHUB_WORKSPACE/removed_a.txt"
printf 'remove b\n' > "$GITHUB_WORKSPACE/removed_b.txt"
printf 'original type\n' > "$GITHUB_WORKSPACE/type_change.txt"
git -C "$GITHUB_WORKSPACE" add .
git -C "$GITHUB_WORKSPACE" commit -qm 'fixture: add service inputs'
base_sha="$(git -C "$GITHUB_WORKSPACE" rev-parse HEAD)"

printf 'changed a\n' > "$GITHUB_WORKSPACE/service_a.txt"
rm "$GITHUB_WORKSPACE/removed_a.txt"
git -C "$GITHUB_WORKSPACE" add -A
git -C "$GITHUB_WORKSPACE" commit -qm 'fixture: change first queued service'
first_sha="$(git -C "$GITHUB_WORKSPACE" rev-parse HEAD)"

printf 'changed b\n' > "$GITHUB_WORKSPACE/service_b.txt"
printf 'added path\n' > "$GITHUB_WORKSPACE/path with spaces.txt"
printf 'added utf8\n' > "$GITHUB_WORKSPACE/café.txt"
printf 'added newline path\n' > "$GITHUB_WORKSPACE/"$'line\nbreak.txt'
rm "$GITHUB_WORKSPACE/type_change.txt"
ln -s service_b.txt "$GITHUB_WORKSPACE/type_change.txt"
rm "$GITHUB_WORKSPACE/removed_b.txt"
git -C "$GITHUB_WORKSPACE" add -A
git -C "$GITHUB_WORKSPACE" commit -qm 'fixture: change second queued service'
group_sha="$(git -C "$GITHUB_WORKSPACE" rev-parse HEAD)"
fixture_repo="$GITHUB_WORKSPACE"
export GITHUB_SHA="$base_sha"

# shellcheck source=./composite/actions-toolbox/scripts/set_and_print_env.sh
source "${ACTION_DIR}/scripts/set_and_print_env.sh"

tests=0
pass() {
  tests=$((tests + 1))
  echo "ok ${tests} - $1"
}
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() {
  [[ "$1" == "$2" ]] || fail "$3: expected '$1', got '$2'"
}
env_value() { sed -n "s/^${1}=//p" "$GITHUB_ENV" | tail -n 1; }
output_value() { sed -n "s/^${1}=//p" "$GITHUB_OUTPUT" | tail -n 1; }

gh() {
  printf '%s\n' "$*" >> "$GH_CALL_LOG"
  case "$1 $2" in
    'api --paginate')
      # A successful PR file lookup is intentionally incomplete for the group.
      printf '[[{"filename":"service_b.txt","status":"modified"},{"filename":"removed_b.txt","status":"removed"}]]\n'
      ;;
    'pr view')
      printf '{"number":202,"title":"Fixture PR","body":"Fixture body","state":"OPEN","author":{"login":"contributor"},"comments":[],"reviews":[],"labels":[],"reviewRequests":[]}\n'
      ;;
    'release list') printf '\n' ;;
    *) return 1 ;;
  esac
}

run_snapshot() {
  (
    cd "$GITHUB_WORKSPACE"
    export -f gh
    bash "${ACTION_DIR}/scripts/set_and_print_env.sh"
  )
}

check_later_metadata() {
  assert_eq '202' "$(env_value GH_PR)" 'PR metadata after file collection'
  assert_eq "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" "$(env_value GH_REPO_URL)" 'repository URL after file collection'
  assert_eq '[]' "$(env_value GH_REPO_TOPICS)" 'repository topics after file collection'
  grep -q '^GH_LATEST_TAG=' "$GITHUB_ENV" || fail 'tag metadata was not published'
  assert_eq '0.0.1' "$(env_value GH_NEXT_PATCH)" 'version metadata after file collection'
}

write_group_event() {
  jq -n --arg base "$base_sha" --arg head "$group_sha" \
    '{repository:{default_branch:"main",topics:[]},merge_group:{base_sha:$base,head_sha:$head}}' \
    > "$GITHUB_EVENT_PATH"
  export GITHUB_EVENT_NAME='merge_group'
  export GITHUB_REF_NAME='gh-readonly-queue/main/pr-202-fixture'
}

check_commit_metadata() {
  local sha="$1"
  : > "$GITHUB_ENV"
  set_repository_env >/dev/null
  set_additional_env >/dev/null
  assert_eq "${sha:0:8}" "$(env_value GIT_SHORT_HASH)" 'short commit hash'
  assert_eq "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${sha}" \
    "$(env_value GH_COMMIT_URL)" 'commit URL'
  assert_eq "$base_sha" "$GITHUB_SHA" 'event SHA is preserved'
}

write_group_event
git -C "$GITHUB_WORKSPACE" checkout -q --detach "$group_sha"
check_commit_metadata "$group_sha"
pass 'detached checkout drives both commit variables, with target repository URL'

export GITHUB_WORKSPACE="${TEST_ROOT}/no-checkout"
mkdir -p "$GITHUB_WORKSPACE"
check_commit_metadata "$base_sha"
pass 'missing checkout falls back to the event SHA, even from another git worktree'

unset ACTIONS_TOOLBOX_MARKER ACTIONS_TOOLBOX_WORKTREE
: > "$GITHUB_ENV"
bash "$PLANNER" write-marker >/dev/null
ACTIONS_TOOLBOX_MARKER="$(env_value ACTIONS_TOOLBOX_MARKER)"
ACTIONS_TOOLBOX_WORKTREE="$(env_value ACTIONS_TOOLBOX_WORKTREE)"
export ACTIONS_TOOLBOX_MARKER ACTIONS_TOOLBOX_WORKTREE
export GITHUB_WORKSPACE="$fixture_repo"
: > "$GITHUB_OUTPUT"
bash "$PLANNER" >/dev/null
assert_eq 'true' "$(output_value run-snapshot)" 'checkout added after snapshot'
pass 'adding a checkout invalidates a metadata snapshot collected without one'

: > "$GITHUB_ENV"
bash "$PLANNER" write-marker >/dev/null
ACTIONS_TOOLBOX_MARKER="$(env_value ACTIONS_TOOLBOX_MARKER)"
ACTIONS_TOOLBOX_WORKTREE="$(env_value ACTIONS_TOOLBOX_WORKTREE)"
export ACTIONS_TOOLBOX_MARKER ACTIONS_TOOLBOX_WORKTREE
: > "$GITHUB_OUTPUT"
bash "$PLANNER" >/dev/null
assert_eq 'false' "$(output_value run-snapshot)" 'same checkout snapshot reuse'
git -C "$GITHUB_WORKSPACE" checkout -q --detach "$first_sha"
: > "$GITHUB_OUTPUT"
bash "$PLANNER" >/dev/null
assert_eq 'true' "$(output_value run-snapshot)" 'changed checkout snapshot refresh'
check_commit_metadata "$first_sha"
git -C "$GITHUB_WORKSPACE" checkout -q --detach "$group_sha"
pass 'same checkout reuses metadata; changing HEAD refreshes it'

: > "$GITHUB_ENV"
: > "$GH_CALL_LOG"
set_changed_files_env >/dev/null
expected_changed='["café.txt","line\nbreak.txt","path with spaces.txt","service_a.txt","service_b.txt","type_change.txt"]'
expected_deleted='["removed_a.txt","removed_b.txt"]'
assert_eq "$expected_changed" "$(env_value FILES_CHANGED)" 'all grouped changed files'
assert_eq "$expected_deleted" "$(env_value FILES_DELETED)" 'all grouped deleted files'
[[ ! -s "$GH_CALL_LOG" ]] || fail 'merge-group file collection called the single-PR API'
pass 'complete merge group ignores a successful but partial PR file API'

jq -n '{pull_request:{number:202}}' > "$GITHUB_EVENT_PATH"
export GITHUB_EVENT_NAME='pull_request'
: > "$GITHUB_ENV"
set_changed_files_env >/dev/null
assert_eq '["service_b.txt"]' "$(env_value FILES_CHANGED)" 'normal PR changed files'
assert_eq '["removed_b.txt"]' "$(env_value FILES_DELETED)" 'normal PR deleted files'
grep -Fq '/pulls/202/files?per_page=100' "$GH_CALL_LOG" || fail 'normal PR did not use its file API'
pass 'normal PR metadata retains its per-PR API behavior'

write_group_event
git clone -q --depth=1 "file://${fixture_repo}" "${TEST_ROOT}/shallow"
export GITHUB_WORKSPACE="${TEST_ROOT}/shallow"
: > "$GITHUB_OUTPUT"
bash "$PLANNER" >/dev/null
assert_eq 'true' "$(output_value run-snapshot)" 'same SHA in a different checkout'
pass 'moving the checkout refreshes metadata even when HEAD is unchanged'
if git -C "$GITHUB_WORKSPACE" cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
  fail 'shallow fixture unexpectedly contains the base commit'
fi
config_before="$(git -C "$GITHUB_WORKSPACE" config --local --list)"
: > "$GITHUB_ENV"
: > "$GH_CALL_LOG"
set_changed_files_env >/dev/null
assert_eq "$expected_changed" "$(env_value FILES_CHANGED)" 'shallow grouped changed files'
assert_eq "$expected_deleted" "$(env_value FILES_DELETED)" 'shallow grouped deleted files'
assert_eq "$config_before" "$(git -C "$GITHUB_WORKSPACE" config --local --list)" 'checkout configuration is preserved'
[[ ! -s "$GH_CALL_LOG" ]] || fail 'shallow merge group used the PR file API'
pass 'shallow checkout fetches missing history without persisting auth configuration'

export GITHUB_WORKSPACE="$fixture_repo"
: > "$GITHUB_ENV"
run_snapshot > "${TEST_ROOT}/complete-snapshot.log" 2>&1
assert_eq "$expected_changed" "$(env_value FILES_CHANGED)" 'complete snapshot files'
check_later_metadata
pass 'complete snapshots still publish all categories and succeed'

git clone -q --depth=1 "file://${fixture_repo}" "${TEST_ROOT}/unavailable"
export GITHUB_WORKSPACE="${TEST_ROOT}/unavailable"
git -C "$GITHUB_WORKSPACE" remote set-url origin "file://${TEST_ROOT}/missing-origin"
: > "$GITHUB_ENV"
INPUT_MARKER_MODE=refresh bash "$PLANNER" >/dev/null
snapshot_status=0
run_snapshot > "${TEST_ROOT}/failed-range.log" 2>&1 || snapshot_status=$?
assert_eq '1' "$snapshot_status" 'incomplete snapshot exit status'
assert_eq 'null' "$(env_value FILES_CHANGED)" 'unavailable changed files'
assert_eq 'null' "$(env_value FILES_DELETED)" 'unavailable deleted files'
assert_eq "${group_sha:0:8}" "$(env_value GIT_SHORT_HASH)" 'commit metadata before file failure'
assert_eq "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${group_sha}" \
  "$(env_value GH_COMMIT_URL)" 'matching URL before file failure'
check_later_metadata
assert_eq '' "$(env_value ACTIONS_TOOLBOX_MARKER)" 'failed snapshot stays invalidated'
grep -Fq 'Cannot collect the complete merge-group file range' "${TEST_ROOT}/failed-range.log" \
  || fail 'unavailable range has no clear error'
pass 'unavailable history publishes later metadata while retaining failure and an invalidated snapshot'

export GITHUB_WORKSPACE="${TEST_ROOT}/no-checkout"
: > "$GITHUB_ENV"
snapshot_status=0
run_snapshot > "${TEST_ROOT}/no-checkout.log" 2>&1 || snapshot_status=$?
assert_eq '1' "$snapshot_status" 'no-checkout snapshot exit status'
assert_eq 'null' "$(env_value FILES_CHANGED)" 'no-checkout changed files'
assert_eq 'null' "$(env_value FILES_DELETED)" 'no-checkout deleted files'
check_later_metadata
pass 'a missing checkout does not suppress unrelated snapshot metadata'

jq -n --arg head "$group_sha" '{merge_group:{head_sha:$head}}' > "$GITHUB_EVENT_PATH"
export GITHUB_WORKSPACE="$fixture_repo"
: > "$GITHUB_ENV"
if set_changed_files_env > "${TEST_ROOT}/missing-base.log" 2>&1; then
  fail 'merge group without base SHA succeeded'
fi
assert_eq 'null' "$(env_value FILES_CHANGED)" 'missing group base'
pass 'missing group base is unknown rather than a single-commit diff'

echo "1..${tests}"
echo 'PASS: worktree and merge-group metadata fixtures'
