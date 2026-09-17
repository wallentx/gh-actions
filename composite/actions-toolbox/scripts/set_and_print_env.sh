#!/usr/bin/env bash
set -euo pipefail

# Description: This script sets environment variables based on the properties of a GitHub repository and event,
#              including various timestamps and identifiers tied to pull request reviews
#              and merges, and release-versus-pre-release status.

# Set -x if VERBOSE is set
if [[ "${RUNNER_VERBOSE:-0}" == "1" ]]; then
  set -x
fi

# -----------------------------
# Environment Variable Setup
# -----------------------------

# Export existing GITHUB_ variables to the environment
while IFS='=' read -r name value; do
  export "$name=$value"
done < <(env | grep '^GITHUB_')

# Function to convert seconds into a readable format (weeks, days, hours, minutes, seconds)
format_time() {
  local total_seconds=$1
  local weeks=$((total_seconds / 604800))       # 1 week = 604800 seconds
  local days=$(( (total_seconds % 604800) / 86400 ))  # 1 day = 86400 seconds
  local hours=$(( (total_seconds % 86400) / 3600 ))   # 1 hour = 3600 seconds
  local minutes=$(( (total_seconds % 3600) / 60 ))    # 1 minute = 60 seconds
  local seconds=$((total_seconds % 60))
  # Create a formatted string
  local result=""
  ((weeks > 0)) && result+="$weeks weeks "
  ((days > 0)) && result+="$days days "
  ((hours > 0)) && result+="$hours hours "
  ((minutes > 0)) && result+="$minutes minutes "
  ((seconds > 0)) && result+="$seconds seconds"

  echo "$result"
}

# Function to set and print environment variables
append_to_github_env() {
    local var_name="$1"
    local var_value="$2"
    local delimiter

    if [[ "$var_value" == *$'\n'* ]]; then
        delimiter="EOF_${var_name}_${$}_${RANDOM}"
        while [[ "$var_value" == *"$delimiter"* ]]; do
            delimiter="${delimiter}_${RANDOM}"
        done
        {
            echo "${var_name}<<${delimiter}"
            echo "$var_value"
            echo "${delimiter}"
        } >>"$GITHUB_ENV"
    else
        echo "${var_name}=${var_value}" >>"$GITHUB_ENV"
    fi
}

sEnv() {
    local var_name="$1"
    shift
    local raw_input=("$@")  # Preserve array elements
    local var_value
    # Use envsubst to safely substitute variables
    var_value="$(echo "${raw_input[*]}" | envsubst)"
    # Attempt to set the variable
    export "${var_name}=${var_value}" || {
        export "${var_name}="
        echo "${var_name}=" >>"$GITHUB_ENV"
        echo "Failed to set ${var_name}. Setting it to empty."
        return
    }
    # Append to GITHUB_ENV
    append_to_github_env "$var_name" "$var_value"
    # Echo the variable
    echo "${var_name}=${var_value}"
    # Verify if the variable was set correctly
    if [[ "$var_value" != *$'\n'* && "${!var_name}" != "$var_value" ]]; then
        export "${var_name}="
        echo "${var_name}=" >>"$GITHUB_ENV"
        echo "Failed to set ${var_name}. Setting it to empty."
    fi
}

sEnvRaw() {
    local var_name="$1"
    shift
    local var_value="${1-}"
    export "${var_name}=${var_value}" || {
        export "${var_name}="
        echo "${var_name}=" >>"$GITHUB_ENV"
        echo "Failed to set ${var_name}. Setting it to empty."
        return
    }
    append_to_github_env "$var_name" "$var_value"
    echo "${var_name}=${var_value}"
    if [[ "$var_value" != *$'\n'* && "${!var_name}" != "$var_value" ]]; then
        export "${var_name}="
        echo "${var_name}=" >>"$GITHUB_ENV"
        echo "Failed to set ${var_name}. Setting it to empty."
    fi
}

paths_to_json_array() {
    jq -R -s -c 'split("\n") | map(select(length > 0)) | unique'
}

git_changed_files_json() {
    local diff_filter="$1"
    local base_sha="${2-}"
    local head_sha="${3:-$GITHUB_SHA}"

    if [[ -n "$base_sha" && "$base_sha" != "0000000000000000000000000000000000000000" ]]; then
        git diff -M -C --name-only --diff-filter="$diff_filter" "$base_sha" "$head_sha" | paths_to_json_array
    else
        git diff-tree -M -C --diff-filter="$diff_filter" --no-commit-id --name-only -r -m "$head_sha" | paths_to_json_array
    fi
}

push_payload_changed_files_json() {
    local change_kind="$1"

    case "$change_kind" in
        changed)
            jq -c '[.commits[]? | (.added[]?, .modified[]?)] | unique' "$GITHUB_EVENT_PATH"
            ;;
        deleted)
            jq -c '[.commits[]? | .removed[]?] | unique' "$GITHUB_EVENT_PATH"
            ;;
    esac
}

pr_api_changed_files_json() {
    local pr_number="$1"
    local change_kind="$2"
    local jq_filter

    case "$change_kind" in
        changed)
            jq_filter='[.[][] | select(.status == "added" or .status == "modified" or .status == "changed" or .status == "renamed" or .status == "copied") | .filename] | unique'
            ;;
        deleted)
            jq_filter='[.[][] | select(.status == "removed") | .filename] | unique'
            ;;
    esac

    gh api --paginate --slurp "/repos/${GITHUB_REPOSITORY}/pulls/${pr_number}/files?per_page=100" | jq -c "$jq_filter"
}

event_range_base_sha() {
    jq -r '.pull_request.base.sha // .merge_group.base_sha // .before // empty' "$GITHUB_EVENT_PATH"
}

event_range_head_sha() {
    jq -r '.pull_request.head.sha // .merge_group.head_sha // .after // env.GITHUB_SHA' "$GITHUB_EVENT_PATH"
}

event_pr_number() {
    local event_name="${GITHUB_EVENT_NAME:-}"
    local pr_number=""

    case "$event_name" in
        pull_request | pull_request_target)
            jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH"
            ;;
        issue_comment)
            jq -r 'if .issue.pull_request != null then (.issue.number // empty) else empty end' \
              "$GITHUB_EVENT_PATH"
            ;;
        merge_group)
            if [[ "${GITHUB_REF_NAME:-}" =~ ^.*pr-([0-9]+)- ]]; then
                pr_number="${BASH_REMATCH[1]}"
            fi
            printf '%s\n' "$pr_number"
            ;;
    esac
}

set_changed_file_env_raw() {
    local var_name="$1"
    local var_value="$2"

    if ! sEnvRaw "$var_name" "$var_value"; then
        echo "Warning: Failed to export ${var_name}; continuing without changed-file metadata." >&2
    fi
}

# -----------------------------
# Environment Variable Categories
# -----------------------------

# Category: Basic Repository Info
set_basic_repository_env() {
    local repo_name="${GITHUB_REPOSITORY#*/}"
    # Set REPO
    sEnv REPO "$repo_name" || sEnv REPO ""
    # Set GH_REPO_NAME (same as REPO)
    sEnv GH_REPO_NAME "$repo_name" || sEnv GH_REPO_NAME ""
    # Set RFC_REPO
    sEnv RFC_REPO "$(sed 's/\./-/g; s/_/-/g' <<<"$repo_name")" || sEnv RFC_REPO ""
}

# Category: Release Info
set_release_env() {
    local release_event="false"
    local release_pre_release="false"
    local release_tag=""
    local full_release="false"
    local gh_event_action=""
    # Set GH_EVENT_NAME and GH_EVENT_ACTION
    sEnv GH_EVENT_NAME "$GITHUB_EVENT_NAME" || sEnv GH_EVENT_NAME ""
    gh_event_action="$(jq -r '.action' "$GITHUB_EVENT_PATH")" || gh_event_action=""
    sEnv GH_EVENT_ACTION "$gh_event_action" || sEnv GH_EVENT_ACTION ""
    # Check if the event is a release published
    if [ "$GITHUB_EVENT_NAME" == 'release' ] && [ "$gh_event_action" == 'published' ]; then
      release_event="true"
      release_pre_release="$(jq -r '.release.prerelease' "$GITHUB_EVENT_PATH")" || release_pre_release="false"
      release_tag="$(jq -r '.release.tag_name' "$GITHUB_EVENT_PATH")" || release_tag=""
      if [ "${release_pre_release:-true}" = false ]; then
        full_release="true"
      else
        full_release="false"
      fi
    fi
    # Set environment variables with fallback to empty if failed
    sEnv RELEASE "$release_event" || sEnv RELEASE ""
    sEnv PRE_RELEASE "$release_pre_release" || sEnv PRE_RELEASE ""
    sEnv RELEASE_TAG "$release_tag" || sEnv RELEASE_TAG ""
    sEnv FULL_RELEASE "$full_release" || sEnv FULL_RELEASE ""
}

# Category: Repository Info
set_repository_env() {
    local repo_name="${GITHUB_REPOSITORY#*/}"
    # Set GH_WORKFLOW_URL
    sEnv GH_WORKFLOW_URL "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}" || sEnv GH_WORKFLOW_URL ""
    # Set GPR_PROJECT
    sEnv GPR_PROJECT "ghcr.io/${GITHUB_REPOSITORY_OWNER:-default_owner}/$repo_name" || sEnv GPR_PROJECT ""
    # Set GH_DEFAULT_BRANCH
    sEnv GH_DEFAULT_BRANCH "$(jq -r '.repository.default_branch' "$GITHUB_EVENT_PATH")" || sEnv GH_DEFAULT_BRANCH ""
    # Set GIT_SHORT_HASH
    sEnv GIT_SHORT_HASH "$(echo "${GITHUB_SHA}" | cut -c1-8)" || sEnv GIT_SHORT_HASH ""
    # Set GH_REPO_REQUIRED_REVIEWS
    # Note: This may fail if permissions are lacking
    # This needs Administrative: read
    # sEnv GH_REPO_REQUIRED_REVIEWS "$(gh api /repos/${GITHUB_REPOSITORY}/branches/${GH_DEFAULT_BRANCH}/protection --jq '.required_pull_request_reviews.required_approving_review_count')" || sEnv GH_REPO_REQUIRED_REVIEWS ""
}

# Category: Changed Files
set_changed_files_env() {
    local event_name="${GITHUB_EVENT_NAME:-}"
    local files_changed="[]"
    local files_deleted="[]"
    local pr_number=""
    local base_sha=""
    local head_sha="${GITHUB_SHA:-}"
    local changed_files_collected="false"

    if [[ "$event_name" == "push" ]]; then
        base_sha="$(event_range_base_sha)" || base_sha=""
        head_sha="$(event_range_head_sha)" || head_sha="${GITHUB_SHA:-}"
        if [[ -n "$base_sha" && "$base_sha" != "0000000000000000000000000000000000000000" ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            if files_changed="$(git_changed_files_json ACMR "$base_sha" "$head_sha")" && files_deleted="$(git_changed_files_json D "$base_sha" "$head_sha")"; then
                changed_files_collected="true"
            else
                echo "Warning: Failed to collect changed files from git metadata for push ${base_sha}..${head_sha:-HEAD}; falling back to push payload." >&2
                files_changed="[]"
                files_deleted="[]"
            fi
        fi
        if [[ "$changed_files_collected" != "true" ]]; then
            files_changed="$(push_payload_changed_files_json changed)" || {
                echo "Warning: Failed to collect changed files from push event payload." >&2
                files_changed="[]"
            }
            files_deleted="$(push_payload_changed_files_json deleted)" || {
                echo "Warning: Failed to collect deleted files from push event payload." >&2
                files_deleted="[]"
            }
            changed_files_collected="true"
        fi
    elif [[ "$event_name" == "pull_request" || "$event_name" == "pull_request_target" || "$event_name" == "issue_comment" ]]; then
        pr_number="$(event_pr_number)" || pr_number=""
        if [[ -n "$pr_number" ]]; then
            if files_changed="$(pr_api_changed_files_json "$pr_number" changed)" && files_deleted="$(pr_api_changed_files_json "$pr_number" deleted)"; then
                changed_files_collected="true"
            else
                echo "Warning: Failed to collect changed files from GitHub API for PR $pr_number." >&2
                files_changed="[]"
                files_deleted="[]"
            fi
        elif [[ "$event_name" == "issue_comment" ]]; then
            # An issue_comment can target an issue or a pull request. Plain issue
            # comments have no meaningful PR changed-file set.
            changed_files_collected="true"
        else
            echo "Warning: ${event_name} event payload did not contain pull_request.number; falling back to git changed file detection." >&2
        fi
    elif [[ "$event_name" == "merge_group" ]]; then
        pr_number="$(event_pr_number)" || pr_number=""
        if [[ -n "$pr_number" ]]; then
            if files_changed="$(pr_api_changed_files_json "$pr_number" changed)" && files_deleted="$(pr_api_changed_files_json "$pr_number" deleted)"; then
                changed_files_collected="true"
            else
                echo "Warning: Failed to collect changed files from GitHub API for merge-group PR $pr_number." >&2
                files_changed="[]"
                files_deleted="[]"
            fi
        else
            echo "Warning: Could not extract PR number from merge_group ref '${GITHUB_REF_NAME:-}'; falling back to git changed file detection." >&2
        fi
    fi

    if [[ "$changed_files_collected" != "true" && "$event_name" != "push" ]]; then
        base_sha="$(event_range_base_sha)" || base_sha=""
        head_sha="$(event_range_head_sha)" || head_sha="${GITHUB_SHA:-}"
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            if files_changed="$(git_changed_files_json ACMR "$base_sha" "$head_sha")" && files_deleted="$(git_changed_files_json D "$base_sha" "$head_sha")"; then
                changed_files_collected="true"
            else
                echo "Warning: Failed to collect changed files from git metadata for ${base_sha:-single commit}..${head_sha:-HEAD}." >&2
                files_changed="[]"
                files_deleted="[]"
            fi
        else
            echo "Warning: GITHUB_WORKSPACE is not a git worktree; skipping git changed file fallback." >&2
        fi
    fi

    if ! jq -e 'type == "array"' >/dev/null <<< "$files_changed"; then
        echo "Warning: FILES_CHANGED metadata was not a JSON array; using []." >&2
        files_changed="[]"
    fi
    if ! jq -e 'type == "array"' >/dev/null <<< "$files_deleted"; then
        echo "Warning: FILES_DELETED changed-file metadata was not a JSON array; using []." >&2
        files_deleted="[]"
    fi

    set_changed_file_env_raw FILES_CHANGED "$files_changed"
    set_changed_file_env_raw FILES_DELETED "$files_deleted"
    return 0
}

# Read from the event payload, which already carries these: no API call, no
# token. The payload on disk never changes, so this is a snapshot from when the
# event fired — see the README for what that costs a consumer.
pr_metadata_from_event() { # event-path -> {labels,reviewers,teams}
    local event_path="${1:-}"
    [[ -n "$event_path" && -f "$event_path" ]] || return 1
    jq -e -c '
      .pull_request // empty
      | {
          labels: [.labels[]?.name],
          reviewers: [.requested_reviewers[]?.login],
          teams: [.requested_teams[]?.slug]
        }' "$event_path" 2>/dev/null
}

# Same shape for events whose payload has no pull_request object of its own.
# gh returns users and teams in one reviewRequests array, which is why the
# split below keys off login rather than a type field.
pr_metadata_from_payload() { # gh pr view JSON on stdin -> {labels,reviewers,teams}
    jq -e -c '
      {
        labels: [.labels[]?.name],
        reviewers: [.reviewRequests[]? | select(.login != null) | .login],
        teams: [.reviewRequests[]? | select(.login == null) | (.slug // .name)
                | select(. != null)]
      }' 2>/dev/null
}

pr_refs_from_event() { # event-path -> {head_ref,head_sha,base_ref,base_sha}
    local event_path="${1:-}"
    [[ -n "$event_path" && -f "$event_path" ]] || return 1
    jq -e -c '
      .pull_request // empty
      | {
          head_ref: (.head.ref // ""),
          head_sha: (.head.sha // ""),
          base_ref: (.base.ref // ""),
          base_sha: (.base.sha // "")
        }' "$event_path" 2>/dev/null
}

pr_refs_from_payload() { # gh pr view JSON on stdin -> {head_ref,head_sha,base_ref,base_sha}
    jq -e -c '
      {
        head_ref: (.headRefName // ""),
        head_sha: (.headRefOid // ""),
        base_ref: (.baseRefName // ""),
        base_sha: (.baseRefOid // "")
      }' 2>/dev/null
}

# Category: PR Info
set_pr_env() {
    PR_PAYLOAD=""
    local event_name="${GITHUB_EVENT_NAME:-}"
    local pr_number=""
    local pr_json_fields='number,title,body,url,state,isDraft,author,headRefName,headRefOid,baseRefName,baseRefOid,createdAt,mergedAt,updatedAt,reviews,comments,reviewDecision,labels,reviewRequests'
    local fallback_pr_json_fields='number,title,body,url,state,isDraft,author,headRefName,headRefOid,baseRefName,baseRefOid,createdAt,mergedAt,updatedAt,labels,reviewRequests'
    local use_sha_fallback="false"

    pr_number="$(event_pr_number)" || pr_number=""
    if [[ -n "$pr_number" ]]; then
        if [[ "$event_name" == "merge_group" ]]; then
            sEnv MERGE_GROUP_PR "$pr_number" || sEnv MERGE_GROUP_PR ""
        fi
        PR_PAYLOAD=$(gh pr view "$pr_number" --repo "$GITHUB_REPOSITORY" --json \
          "$pr_json_fields" --jq '.') || {
            echo "Warning: Failed to fetch PR details for PR number $pr_number" >&2
            PR_PAYLOAD=""
        }
    elif [[ "$event_name" == "pull_request" || "$event_name" == "pull_request_target" ]]; then
        echo "Warning: ${event_name} event payload did not contain pull_request.number; falling back to SHA lookup for $GITHUB_SHA" >&2
        use_sha_fallback="true"
    elif [[ "$event_name" == "merge_group" ]]; then
        echo "Warning: Could not extract PR number from merge_group ref '${GITHUB_REF_NAME:-}'." >&2
    elif [[ "$event_name" != "issue_comment" ]]; then
        use_sha_fallback="true"
    fi

    if [[ "$use_sha_fallback" == "true" ]]; then
        # Not in a recognized PR context; try to find the most recent merged PR
        # associated with GITHUB_SHA.
        PR_PAYLOAD=$(gh pr list --repo "$GITHUB_REPOSITORY" --search "$GITHUB_SHA" --state merged --json \
          "$fallback_pr_json_fields" --jq '.[0] // empty') || {
            echo "Warning: No PR found for commit $GITHUB_SHA" >&2
            PR_PAYLOAD=""
        }
    fi

    if [[ "$event_name" == "issue_comment" ]]; then
        local event_comment_body_json='""'
        local event_comment_body_truncated='false'
        event_comment_body_json="$(jq -cr --argjson limit 200 '(.comment.body // "")[0:$limit] | @json' "$GITHUB_EVENT_PATH")" \
          || event_comment_body_json='""'
        event_comment_body_truncated="$(jq -r --argjson limit 200 '((.comment.body // "") | length) > $limit' "$GITHUB_EVENT_PATH")" \
          || event_comment_body_truncated='false'
        sEnvRaw GH_EVENT_COMMENT_BODY_JSON "$event_comment_body_json" \
          || sEnvRaw GH_EVENT_COMMENT_BODY_JSON '""'
        sEnv GH_EVENT_COMMENT_BODY_TRUNCATED "$event_comment_body_truncated" \
          || sEnv GH_EVENT_COMMENT_BODY_TRUNCATED 'false'
    fi
    # Event payload wins, so these survive a failed lookup above or no token at
    # all; the fetched payload is only a fallback.
    local pr_meta=""
    pr_meta="$(pr_metadata_from_event "${GITHUB_EVENT_PATH:-}")" || pr_meta=""
    if [[ -z "$pr_meta" && -n "$PR_PAYLOAD" ]]; then
        pr_meta="$(pr_metadata_from_payload <<<"$PR_PAYLOAD")" || pr_meta=""
    fi
    if [[ -n "$pr_meta" ]]; then
        sEnvRaw GH_PR_LABELS "$(jq -c '.labels' <<<"$pr_meta")" || sEnvRaw GH_PR_LABELS "[]"
        sEnvRaw GH_PR_REQUESTED_REVIEWERS "$(jq -c '.reviewers' <<<"$pr_meta")" || sEnvRaw GH_PR_REQUESTED_REVIEWERS "[]"
        sEnvRaw GH_PR_REQUESTED_TEAMS "$(jq -c '.teams' <<<"$pr_meta")" || sEnvRaw GH_PR_REQUESTED_TEAMS "[]"
    fi

    local pr_refs=""
    pr_refs="$(pr_refs_from_event "${GITHUB_EVENT_PATH:-}")" || pr_refs=""
    if [[ -z "$pr_refs" && -n "$PR_PAYLOAD" ]]; then
        pr_refs="$(pr_refs_from_payload <<<"$PR_PAYLOAD")" || pr_refs=""
    fi
    if [[ -n "$pr_refs" ]]; then
        sEnvRaw GH_PR_HEAD_REF "$(jq -r '.head_ref' <<<"$pr_refs")" || sEnvRaw GH_PR_HEAD_REF ""
        sEnv GH_PR_HEAD_SHA "$(jq -r '.head_sha' <<<"$pr_refs")" || sEnv GH_PR_HEAD_SHA ""
        sEnvRaw GH_PR_BASE_REF "$(jq -r '.base_ref' <<<"$pr_refs")" || sEnvRaw GH_PR_BASE_REF ""
        sEnv GH_PR_BASE_SHA "$(jq -r '.base_sha' <<<"$pr_refs")" || sEnv GH_PR_BASE_SHA ""
    fi

    # If PR_PAYLOAD is populated, extract details and set environment variables
    if [[ -n "$PR_PAYLOAD" ]]; then
        GH_PR_NUMBER=$(echo "$PR_PAYLOAD" | jq -r '.number // empty')
        GH_PR_TITLE=$(echo "$PR_PAYLOAD" | jq -r '.title // empty')
        GH_PR_BODY_JSON=$(echo "$PR_PAYLOAD" | jq -cr '.body // empty | @json')
        GH_PR_AUTHOR=$(echo "$PR_PAYLOAD" | jq -r '.author.login // empty')
        GH_PR_URL=$(echo "$PR_PAYLOAD" | jq -r '.url // empty')
        GH_PR_STATE=$(echo "$PR_PAYLOAD" | jq -r '.state // empty')
        GH_PR_CREATED_AT=$(echo "$PR_PAYLOAD" | jq -r '.createdAt // empty')
        GH_PR_MERGED_AT=$(echo "$PR_PAYLOAD" | jq -r '.mergedAt // empty')
        GH_PR_UPDATED_AT=$(echo "$PR_PAYLOAD" | jq -r '.updatedAt // empty')
        GH_PR_IS_DRAFT=$(echo "$PR_PAYLOAD" | jq -r '.isDraft // empty')
        GH_PR_REVIEWS=$(echo "$PR_PAYLOAD" | jq -c '.reviews // []')
        local pr_comments_meta=''
        pr_comments_meta=$(echo "$PR_PAYLOAD" | jq -c --argjson body_limit 200 --argjson count_limit 20 '
          (.comments? // [] | arrays) as $all
          | ($all
              | if length > $count_limit then .[-$count_limit:] else . end
              | map(
                  (.body // "") as $body
                  | {
                      user: (.author.login // ""),
                      comment_url: (.url // ""),
                      body: $body[0:$body_limit],
                      body_truncated: (($body | length) > $body_limit)
                    }
                )) as $summaries
          | {
              comments: ($summaries | map(del(.body_truncated))),
              truncated: ((($all | length) > $count_limit) or any($summaries[]; .body_truncated))
            }
        ')
        GH_PR_COMMENTS=$(jq -c '.comments' <<<"$pr_comments_meta")
        GH_PR_COMMENTS_TRUNCATED=$(jq -r '.truncated' <<<"$pr_comments_meta")
        # Set environment variables
        sEnv GH_PR "$GH_PR_NUMBER" || sEnv GH_PR ""
        sEnvRaw GH_PR_TITLE "$GH_PR_TITLE" || sEnvRaw GH_PR_TITLE ""
        sEnvRaw GH_PR_BODY_JSON "$GH_PR_BODY_JSON" || sEnvRaw GH_PR_BODY_JSON ""
        sEnvRaw GH_PR_AUTHOR "$GH_PR_AUTHOR" || sEnvRaw GH_PR_AUTHOR ""
        sEnv GH_PR_URL "$GH_PR_URL" || sEnv GH_PR_URL ""
        sEnv GH_PR_STATE "$GH_PR_STATE" || sEnv GH_PR_STATE ""
        sEnv GH_PR_CREATED_AT "$GH_PR_CREATED_AT" || sEnv GH_PR_CREATED_AT ""
        sEnv GH_PR_MERGED_AT "$GH_PR_MERGED_AT" || sEnv GH_PR_MERGED_AT ""
        sEnv GH_PR_UPDATED_AT "$GH_PR_UPDATED_AT" || sEnv GH_PR_UPDATED_AT ""
        sEnv GH_PR_IS_DRAFT "$GH_PR_IS_DRAFT" || sEnv GH_PR_IS_DRAFT ""
        sEnvRaw GH_PR_REVIEWS "$GH_PR_REVIEWS" || sEnvRaw GH_PR_REVIEWS ""
        sEnvRaw GH_PR_COMMENTS "$GH_PR_COMMENTS" || sEnvRaw GH_PR_COMMENTS ""
        sEnv GH_PR_COMMENTS_TRUNCATED "$GH_PR_COMMENTS_TRUNCATED" || sEnv GH_PR_COMMENTS_TRUNCATED "false"
        # Calculate time differences
        if [[ -n "$GH_PR_CREATED_AT" && -n "$GH_PR_MERGED_AT" ]]; then
            MERGED_DIFF_SECONDS=$(( $(date -d "$GH_PR_MERGED_AT" +%s) - $(date -d "$GH_PR_CREATED_AT" +%s) ))
            sEnv GH_PR_TIME_MERGED "$(format_time "$MERGED_DIFF_SECONDS")" || sEnv GH_PR_TIME_MERGED ""
        fi
    fi
}

# Category: Additional Info
set_additional_env() {
    sEnv GH_COMMIT_URL "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}" || sEnv GH_COMMIT_URL ""
    sEnv GH_REPO_URL "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}" || sEnv GH_REPO_URL ""
    sEnv GH_REPO_TOPICS "$(jq -c -r '.repository.topics' "$GITHUB_EVENT_PATH")" || sEnv GH_REPO_TOPICS ""
}

# Category: Versioning Info
set_version_env() {
    GH_WORKTREE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    sEnv GH_WORKTREE_ROOT "$GH_WORKTREE_ROOT" || sEnv GH_WORKTREE_ROOT ""

    if [[ -n "$GH_WORKTREE_ROOT" ]]; then
        # Fetch tags from the caller-provided checkout. This is best-effort so
        # diagnostics still run with read-only or otherwise limited credentials.
        git fetch -tq || true
        # Extract the latest tag
        GH_LATEST_TAG=$(git for-each-ref --sort=-creatordate --count=1 --format='%(refname:short)' refs/tags) || GH_LATEST_TAG=""
        if [[ -n "$GH_LATEST_TAG" ]]; then
            GH_LATEST_TAG_SHA=$(git rev-list -n 1 "$GH_LATEST_TAG") || GH_LATEST_TAG_SHA=""
        else
            GH_LATEST_TAG_SHA=""
        fi
    else
        echo "Warning: GITHUB_WORKSPACE is not a git worktree; skipping git tag metadata." >&2
        GH_LATEST_TAG=""
        GH_LATEST_TAG_SHA=""
    fi

    GH_LATEST_RELEASE_TAG=$(gh release list --limit 1 --json tagName --jq '.[0].tagName // ""') || GH_LATEST_RELEASE_TAG=""
    if [[ -n "$GH_WORKTREE_ROOT" && -n "$GH_LATEST_RELEASE_TAG" ]]; then
        GH_LATEST_RELEASE_TAG_SHA=$(git rev-list -n 1 "$GH_LATEST_RELEASE_TAG") || GH_LATEST_RELEASE_TAG_SHA=""
    else
        GH_LATEST_RELEASE_TAG_SHA=""
    fi

    # Default values for GH_TAG_PREFIX, GH_TAG_SEMVER, and GH_TAG_SUFFIX
    GH_TAG_PREFIX=""
    GH_TAG_SEMVER="0.0.0"
    GH_TAG_SUFFIX=""
    GH_TAG_PRERELEASE=""
    GH_NEXT_MAJOR=""
    GH_NEXT_MINOR=""
    GH_NEXT_PATCH=""
    GH_NEXT_MAJOR_PRERELEASE=""
    GH_NEXT_MINOR_PRERELEASE=""
    GH_NEXT_PATCH_PRERELEASE=""
    GH_NEXT_MAJOR_PRERELEASE_NUM=""
    GH_NEXT_MINOR_PRERELEASE_NUM=""
    GH_NEXT_PATCH_PRERELEASE_NUM=""
    GH_PRERELEASE_TYPE="${GH_PRERELEASE_TYPE:-rc}"
    if ! [[ "$GH_PRERELEASE_TYPE" =~ ^[A-Za-z][A-Za-z0-9.-]*$ ]]; then
        echo "Warning: GH_PRERELEASE_TYPE '$GH_PRERELEASE_TYPE' is invalid; using rc." >&2
        GH_PRERELEASE_TYPE="rc"
    fi

    set_version_env_value() {
        local var_name="$1"
        local var_value="${2-}"

        if [[ -n "$var_value" ]]; then
            sEnv "$var_name" "$var_value" || sEnv "$var_name" "" || true
        else
            sEnv "$var_name" "" || true
        fi
    }

    set_version_metadata_env() {
        set_version_env_value GH_LATEST_TAG "${GH_LATEST_TAG:-}"
        set_version_env_value GH_LATEST_TAG_SHA "${GH_LATEST_TAG_SHA:-}"
        set_version_env_value GH_LATEST_RELEASE_TAG "${GH_LATEST_RELEASE_TAG:-}"
        set_version_env_value GH_LATEST_RELEASE_TAG_SHA "${GH_LATEST_RELEASE_TAG_SHA:-}"
        set_version_env_value GH_NEXT_MAJOR "${GH_NEXT_MAJOR:-}"
        set_version_env_value GH_NEXT_MINOR "${GH_NEXT_MINOR:-}"
        set_version_env_value GH_NEXT_PATCH "${GH_NEXT_PATCH:-}"
        set_version_env_value GH_NEXT_MAJOR_PRERELEASE "${GH_NEXT_MAJOR_PRERELEASE:-}"
        set_version_env_value GH_NEXT_MINOR_PRERELEASE "${GH_NEXT_MINOR_PRERELEASE:-}"
        set_version_env_value GH_NEXT_PATCH_PRERELEASE "${GH_NEXT_PATCH_PRERELEASE:-}"
        set_version_env_value GH_NEXT_MAJOR_PRERELEASE_NUM "${GH_NEXT_MAJOR_PRERELEASE_NUM:-}"
        set_version_env_value GH_NEXT_MINOR_PRERELEASE_NUM "${GH_NEXT_MINOR_PRERELEASE_NUM:-}"
        set_version_env_value GH_NEXT_PATCH_PRERELEASE_NUM "${GH_NEXT_PATCH_PRERELEASE_NUM:-}"
        set_version_env_value GH_TAG_PREFIX "${GH_TAG_PREFIX:-}"
        set_version_env_value GH_TAG_SEMVER "${GH_TAG_SEMVER:-}"
        set_version_env_value GH_TAG_SUFFIX "${GH_TAG_SUFFIX:-}"
        set_version_env_value GH_PRERELEASE_TYPE "${GH_PRERELEASE_TYPE:-}"
    }

    # Extract prefix, version, and suffix
    if [[ -z "$GH_LATEST_TAG" ]]; then
        MAJOR=0
        MINOR=0
        PATCH=0
    elif [[ "$GH_LATEST_TAG" =~ ^([^0-9]*)([0-9]+)(\.([0-9]+))?(\.([0-9]+))?(.*)$ ]]; then
        local tag_remainder="${BASH_REMATCH[7]:-}"
        local prerelease_prefix="-${GH_PRERELEASE_TYPE}"
        local prerelease_rest=""
        GH_TAG_PREFIX="${BASH_REMATCH[1]:-}"  # Explicitly default GH_TAG_PREFIX to empty
        MAJOR="${BASH_REMATCH[2]}"
        MINOR="${BASH_REMATCH[4]:-0}"  # Default to 0 if not present
        PATCH="${BASH_REMATCH[6]:-0}"  # Default to 0 if not present
        if [[ "$tag_remainder" == "$prerelease_prefix"* ]]; then
            prerelease_rest="${tag_remainder#"$prerelease_prefix"}"
            if [[ "$prerelease_rest" =~ ^([0-9]+)(.*)$ ]]; then
                GH_TAG_PRERELEASE="-${GH_PRERELEASE_TYPE}${BASH_REMATCH[1]}"
                GH_TAG_SUFFIX="${BASH_REMATCH[2]:-}"
            else
                echo "Warning: Latest tag '$GH_LATEST_TAG' starts with prerelease prefix '$prerelease_prefix' but does not include a numeric identifier; skipping version increment metadata." >&2
                GH_TAG_PREFIX=""
                GH_TAG_SEMVER=""
                GH_TAG_SUFFIX=""
                set_version_metadata_env
                return 0
            fi
        else
            GH_TAG_SUFFIX="$tag_remainder"
        fi
        if [[ -n "$GH_TAG_SUFFIX" && ! "$GH_TAG_SUFFIX" =~ ^-[A-Za-z0-9][A-Za-z0-9.-]*$ ]]; then
            echo "Warning: Latest tag '$GH_LATEST_TAG' does not match the expected suffix format; skipping version increment metadata." >&2
            GH_TAG_PREFIX=""
            GH_TAG_SEMVER=""
            GH_TAG_SUFFIX=""
            set_version_metadata_env
            return 0
        fi
        GH_TAG_SEMVER="${MAJOR}.${MINOR}.${PATCH}"
    else
        echo "Warning: Latest tag '$GH_LATEST_TAG' does not match the expected format; skipping version increment metadata." >&2
        GH_TAG_PREFIX=""
        GH_TAG_SEMVER=""
        GH_TAG_SUFFIX=""
        set_version_metadata_env
        return 0
    fi
    # Validate that MAJOR, MINOR, and PATCH are integers
    if ! [[ "$MAJOR" =~ ^[0-9]+$ && "$MINOR" =~ ^[0-9]+$ && "$PATCH" =~ ^[0-9]+$ ]]; then
        echo "Error: Version components are not all integers." >&2
        MAJOR=0
        MINOR=0
        PATCH=0
    fi
    # Calculate the next major, minor, and patch versions (ignoring suffix for increments)
    NEXT_MAJOR=$((MAJOR + 1))
    NEXT_MINOR=$((MINOR + 1))
    NEXT_PATCH=$((PATCH + 1))
    NEXT_MAJOR_VERSION="${NEXT_MAJOR}.0.0"
    NEXT_MINOR_VERSION="${MAJOR}.${NEXT_MINOR}.0"
    NEXT_PATCH_VERSION="${MAJOR}.${MINOR}.${NEXT_PATCH}"
    if [[ -n "$GH_TAG_PRERELEASE" ]]; then
        if (( MINOR == 0 && PATCH == 0 )); then
            NEXT_MAJOR_VERSION="${MAJOR}.0.0"
        fi
        if (( PATCH == 0 )); then
            NEXT_MINOR_VERSION="${MAJOR}.${MINOR}.0"
        fi
        NEXT_PATCH_VERSION="${MAJOR}.${MINOR}.${PATCH}"
    fi
    # Reconstruct the new tags with the original prefix and optional suffix
    GH_NEXT_MAJOR="${GH_TAG_PREFIX}${NEXT_MAJOR_VERSION}${GH_TAG_SUFFIX}"
    GH_NEXT_MINOR="${GH_TAG_PREFIX}${NEXT_MINOR_VERSION}${GH_TAG_SUFFIX}"
    GH_NEXT_PATCH="${GH_TAG_PREFIX}${NEXT_PATCH_VERSION}${GH_TAG_SUFFIX}"

    next_prerelease_num() {
        local base_version="$1"
        local tag_prefix="${GH_TAG_PREFIX}${base_version}-${GH_PRERELEASE_TYPE}"
        local latest_prerelease_num=0
        local tag
        local rest
        local num
        local decimal_num

        if [[ -z "$GH_WORKTREE_ROOT" ]]; then
            echo 1
            return
        fi

        while IFS= read -r tag; do
            [[ "$tag" == "$tag_prefix"* ]] || continue
            rest="${tag#"$tag_prefix"}"
            if [[ -n "$GH_TAG_SUFFIX" ]]; then
                [[ "$rest" == *"$GH_TAG_SUFFIX" ]] || continue
                num="${rest%"$GH_TAG_SUFFIX"}"
            else
                num="$rest"
            fi
            [[ "$num" =~ ^[0-9]+$ ]] || continue
            decimal_num=$((10#$num))
            if (( decimal_num > latest_prerelease_num )); then
                latest_prerelease_num="$decimal_num"
            fi
        done < <(git tag --list "${tag_prefix}*" 2>/dev/null || true)

        echo $((latest_prerelease_num + 1))
    }

    GH_NEXT_MAJOR_PRERELEASE_NUM="$(next_prerelease_num "$NEXT_MAJOR_VERSION")"
    GH_NEXT_MINOR_PRERELEASE_NUM="$(next_prerelease_num "$NEXT_MINOR_VERSION")"
    GH_NEXT_PATCH_PRERELEASE_NUM="$(next_prerelease_num "$NEXT_PATCH_VERSION")"

    GH_NEXT_MAJOR_PRERELEASE="${GH_TAG_PREFIX}${NEXT_MAJOR_VERSION}-${GH_PRERELEASE_TYPE}${GH_NEXT_MAJOR_PRERELEASE_NUM}${GH_TAG_SUFFIX}"
    GH_NEXT_MINOR_PRERELEASE="${GH_TAG_PREFIX}${NEXT_MINOR_VERSION}-${GH_PRERELEASE_TYPE}${GH_NEXT_MINOR_PRERELEASE_NUM}${GH_TAG_SUFFIX}"
    GH_NEXT_PATCH_PRERELEASE="${GH_TAG_PREFIX}${NEXT_PATCH_VERSION}-${GH_PRERELEASE_TYPE}${GH_NEXT_PATCH_PRERELEASE_NUM}${GH_TAG_SUFFIX}"

    # Set the environment variables
    set_version_metadata_env
}

# -----------------------------
# Main Execution Flow
# -----------------------------

main() {
    # Categories: Basic Repository Info, Release Info, Repository Info, Changed Files, PR Info, Additional Info, Versioning Info
    set_basic_repository_env
    set_release_env
    set_repository_env
    set_changed_files_env
    set_pr_env
    set_additional_env
    set_version_env
}

# Invoke main unless this file is sourced by its fixture tests.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
