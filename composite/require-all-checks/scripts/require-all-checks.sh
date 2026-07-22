#!/usr/bin/env bash
set -euo pipefail
# Description: Wait for every other pull request or merge-group check to
# settle, then require every remaining check to have an accepted conclusion.
# Consumes EVENT_NAME, PR, CHECK_REF, POLL_SECONDS, QUIET_SECONDS, GH_TOKEN,
# GH_REPO, and GITHUB_RUN_ID.
shopt -s lastpipe

[[ $POLL_SECONDS =~ ^[1-9][0-9]*$ &&
   $QUIET_SECONDS =~ ^[0-9]+$ ]] || {
    echo "poll-seconds must be a positive integer and quiet-seconds must be a non-negative integer" >&2
    exit 2
}

case "$EVENT_NAME" in
    pull_request)
        : "${PR:?A pull_request event must provide a pull request number}"
        ;;
    merge_group)
        : "${CHECK_REF:?A merge_group event must provide a commit SHA}"
        ;;
    *)
        echo "This action requires a pull_request or merge_group event" >&2
        exit 2
        ;;
esac

query_pull_request_checks() {
    gh pr checks "$PR" --json bucket,link --jq '
        map(select(
            .link
            | contains("/actions/runs/'"$GITHUB_RUN_ID"'/")
            | not
        ))
        | [
            ("@" + (map(.link) | sort | join(","))),
            any(.[]; .bucket == "pending"),
            all(.[]; .bucket | IN("pass", "skipping"))
          ]
        | @tsv
    '
}

query_merge_group_checks() {
    local owner="${GH_REPO%%/*}"
    local repository="${GH_REPO#*/}"

    # shellcheck disable=SC2016 # GraphQL variables must remain literal.
    gh api graphql --paginate --slurp \
        -F owner="$owner" \
        -F name="$repository" \
        -F ref="$CHECK_REF" \
        -f query='
            query(
                $owner: String!
                $name: String!
                $ref: String!
                $endCursor: String
            ) {
                repository(owner: $owner, name: $name) {
                    object(expression: $ref) {
                        ... on Commit {
                            statusCheckRollup {
                                contexts(first: 100, after: $endCursor) {
                                    nodes {
                                        __typename
                                        ... on CheckRun {
                                            id
                                            detailsUrl
                                            status
                                            conclusion
                                        }
                                        ... on StatusContext {
                                            id
                                            state
                                        }
                                    }
                                    pageInfo {
                                        hasNextPage
                                        endCursor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        ' |
        jq -r '
            [
                .[]
                | (.data.repository.object.statusCheckRollup.contexts.nodes // [])[]
                | select(
                    .__typename != "CheckRun"
                    or (
                        (.detailsUrl // "")
                        | contains("/actions/runs/'"$GITHUB_RUN_ID"'/")
                        | not
                    )
                )
                | {
                    key: (."__typename" + ":" + .id),
                    pending: (
                        if .__typename == "CheckRun" then
                            .status != "COMPLETED"
                        else
                            .state | IN("EXPECTED", "PENDING")
                        end
                    ),
                    passing: (
                        if .__typename == "CheckRun" then
                            .status == "COMPLETED"
                            and (.conclusion | IN("SUCCESS", "SKIPPED", "NEUTRAL"))
                        else
                            .state == "SUCCESS"
                        end
                    )
                  }
            ]
            | [
                ("@" + (map(.key) | sort | join(","))),
                any(.[]; .pending),
                all(.[]; .passing)
              ]
            | @tsv
        '
}

query_checks() {
    case "$EVENT_NAME" in
        pull_request) query_pull_request_checks ;;
        merge_group) query_merge_group_checks ;;
    esac
}

previous=
stable=0

until
    query_checks | IFS=$'\t' read -r current pending passing

    rc=${PIPESTATUS[0]}
    [[ $current == @* ]] || exit 1
    case "$EVENT_NAME" in
        pull_request)
            ((rc == 0 || rc == 1 || rc == 8)) || exit "$rc"
            ;;
        merge_group)
            ((rc == 0)) || exit "$rc"
            ;;
    esac

    if [[ $current == "$previous" ]]; then
        ((stable += POLL_SECONDS))
    else
        previous=$current
        stable=0
    fi

    ((stable >= QUIET_SECONDS)) && [[ $pending == false ]]
do
    sleep "$POLL_SECONDS"
done

if [[ $passing != true ]]; then
    echo "One or more checks did not resolve to an accepted conclusion." >&2
    exit 1
fi

echo "All other checks passed or were skipped."
