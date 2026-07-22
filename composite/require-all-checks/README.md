# Require all PR checks

## Description

Waits for every other pull request or merge-group check, then succeeds when each passes or is skipped.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `poll-seconds` | Seconds between check queries | No | `10` |
| `quiet-seconds` | Seconds the set of check identifiers must remain unchanged before evaluation | No | `30` |

## Outputs

This action has no outputs.

## Usage

```yaml
permissions:
  checks: read
  contents: read
  pull-requests: read
  statuses: read

jobs:
  all-checks:
    name: All PR checks passed
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: wallentx/gh-actions/composite/require-all-checks@main
```

## How It Works

For `pull_request` events, the action polls `gh pr checks`. For `merge_group` events, it queries the target commit's complete status rollup, including check runs and commit statuses. Both paths ignore checks from the action's own workflow run and wait until the remaining check set has stayed unchanged for `quiet-seconds`. The action succeeds only when no check is pending and every remaining check is passing, skipped, or neutral. Failed, cancelled, or otherwise unsuccessful checks fail the action.

Run exactly one all-checks gate for each pull request or merge group. Two gates in separate workflow runs see each other as pending and wait until their job timeouts.

The action requires a `pull_request` or `merge_group` event with the GitHub CLI and `jq` available on the runner. It uses the job's `github.token`; grant that token `checks: read`, `contents: read`, `pull-requests: read`, and `statuses: read`.
