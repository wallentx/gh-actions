# All PR checks must pass

## Description

Waits for every other check on a pull request to finish, then succeeds only when all checks pass.

## Inputs

This workflow has no inputs.

## Secrets

This workflow requires no secrets. It uses the target repository's `github.token` with read-only access to checks, pull requests, and commit statuses.

## Usage

Select this workflow under the organization or enterprise ruleset rule named **Require workflows to pass before merging**. Ruleset workflows cannot use `workflow_call`; GitHub runs this file from its supported `pull_request` and `merge_group` triggers.

## What It Enforces

On `pull_request`, the workflow waits for every check outside its own workflow run. It succeeds when the check set remains unchanged for 30 seconds, no checks remain pending, and every check is passing or skipped. Failed or cancelled checks fail the gate.

On `merge_group`, the job succeeds without polling because that event has no single pull request number. Pull request checks must pass before the pull request enters the merge queue; merge-group-specific checks should be configured as separate required workflows.

Run exactly one all-checks gate for each pull request. Multiple gates in separate workflow runs see one another as pending and eventually time out.

## Ruleset Configuration

| Setting | Value |
|---------|-------|
| Source repository | `wallentx/gh-actions` |
| Workflow path | `.github/workflows/ruleset-require-all-checks.yml` |
| Recommended ruleset ref | Protected `compliance/stable` branch or protected tag |
| Evaluation ref | `main` is acceptable while the ruleset is in Evaluate mode |

The workflow deliberately calls `wallentx/gh-actions/composite/require-all-checks@main`, so the polling implementation follows the latest `main` revision even when the ruleset workflow itself is selected from a protected ref.

Start rollout in Evaluate mode. Confirm every targeted repository permits this action, has no second all-checks aggregator, and has enough Actions minutes for the 60-minute timeout. Plan a bypass list for repositories where pull request checks cannot run, then advance the protected ruleset ref and enable enforcement.

## Notes

The workflow requests only `checks: read`, `pull-requests: read`, and `statuses: read`. Organization, enterprise, or repository policy can restrict the target repository's token further.

When introducing the composite and this workflow together, `@main` does not contain the composite until the first change lands. Merge the composite first or bypass the initial ruleset run; subsequent runs resolve the composite from `main` normally.
