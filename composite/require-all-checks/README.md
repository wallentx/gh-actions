# Require all PR checks

## Description

Waits until every other check on a pull request finishes, then succeeds only when all checks pass.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `poll-seconds` | Seconds between check queries | No | `10` |
| `quiet-seconds` | Seconds the set of check links must remain unchanged before evaluation | No | `30` |

## Outputs

This action has no outputs.

## Usage

```yaml
permissions:
  checks: read
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

The action polls `gh pr checks`, ignores checks from its own workflow run, and waits until the remaining set of check links has stayed unchanged for `quiet-seconds`. It then succeeds only when no check is pending and every remaining check is passing or skipped. Failed, cancelled, or otherwise unsuccessful checks fail the action.

Run exactly one all-checks gate for each pull request. Two gates in separate workflow runs see each other as pending and wait until their job timeouts.

The action requires a `pull_request` event and the GitHub CLI available on the runner. It uses the job's `github.token`; grant that token `checks: read`, `pull-requests: read`, and `statuses: read`.
