#!/usr/bin/env bash
set -euo pipefail
# Description: Wait for every other PR check to settle, then require every
# remaining check to have a passing or skipped conclusion. Consumes PR,
# POLL_SECONDS, QUIET_SECONDS, GH_TOKEN, GH_REPO, and GITHUB_RUN_ID.
shopt -s lastpipe

: "${PR:?This action requires a pull_request event}"

[[ $POLL_SECONDS =~ ^[1-9][0-9]*$ &&
   $QUIET_SECONDS =~ ^[0-9]+$ ]] || {
    echo "poll-seconds must be a positive integer and quiet-seconds must be a non-negative integer" >&2
    exit 2
}

previous=
stable=0

until
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
    ' | IFS=$'\t' read -r current pending passing

    rc=${PIPESTATUS[0]}
    [[ $current == @* ]] || exit 1
    ((rc == 0 || rc == 1 || rc == 8)) || exit "$rc"

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
    echo "One or more pull request checks did not pass." >&2
    exit 1
fi

echo "All other pull request checks passed or were skipped."
