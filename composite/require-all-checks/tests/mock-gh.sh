#!/usr/bin/env bash
set -euo pipefail
# Description: Emit deterministic gh pr checks output for the composite action
# test workflow. Consumes MOCK_CHECK_RESULT.

case "${MOCK_CHECK_RESULT:-}" in
    pass)
        printf '@https://github.com/example/repo/actions/runs/1/job/1\tfalse\ttrue\n'
        ;;
    fail)
        printf '@https://github.com/example/repo/actions/runs/1/job/1\tfalse\tfalse\n'
        exit 1
        ;;
    *)
        echo "Unsupported MOCK_CHECK_RESULT: ${MOCK_CHECK_RESULT:-<unset>}" >&2
        exit 2
        ;;
esac
