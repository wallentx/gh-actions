#!/usr/bin/env bash
set -euo pipefail
# Description: Emit deterministic GitHub CLI responses for the composite
# action test workflow. Consumes MOCK_CHECK_RESULT.

if [[ ${1:-} == api ]]; then
    case "${MOCK_CHECK_RESULT:-}" in
        pass) conclusion=SUCCESS ;;
        fail) conclusion=FAILURE ;;
        *)
            echo "Unsupported MOCK_CHECK_RESULT: ${MOCK_CHECK_RESULT:-<unset>}" >&2
            exit 2
            ;;
    esac

    printf '[{"data":{"repository":{"object":{"statusCheckRollup":{"contexts":{"nodes":[{"__typename":"CheckRun","id":"test-check","detailsUrl":"https://github.com/example/repo/actions/runs/1/job/1","status":"COMPLETED","conclusion":"%s"},{"__typename":"StatusContext","id":"test-status","state":"SUCCESS"}]}}}}}}]\n' "$conclusion"
    exit 0
fi

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
