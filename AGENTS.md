# Agent Instructions for wallentx/gh-actions Repository

Instructions for AI coding agents working in this repository. Repository-specific Copilot guidance also lives in [.github/copilot-instructions.md](.github/copilot-instructions.md).

## Project Overview

This repository contains reusable GitHub Actions workflows and composite actions that can be referenced from any GitHub Actions workflow in any repository. The primary goal is to provide standardized, well-documented, and maintainable automation that promotes consistency across multiple projects.

**Key Principles:**
- Consistency: Standardize workflows across all repositories
- Maintainability: Update actions in one place, benefit everywhere
- Reusability: Share common functionality across projects
- Version Control: Track changes and pin to specific versions

## Repository Structure

Current repository layout (see the auto-generated index in [README.md](README.md) for public workflows and composite actions):

```
.
├── .github/
│   ├── copilot-instructions.md
│   ├── dependabot.yml
│   └── workflows/
│       ├── termux-run.yml
│       ├── termux-run.md
│       ├── _test-actions-toolbox.yml
│       ├── _test-termux-run.yml
│       └── _update-readme.yml
├── composite/
│   ├── actions-toolbox/
│   │   ├── action.yml
│   │   ├── README.md
│   │   └── scripts/
│   ├── checkout-and-cache/
│   │   ├── action.yml
│   │   └── README.md
│   └── update-md/
│       ├── action.yml
│       └── README.md
├── .gitignore
├── AGENTS.md
└── README.md
```

## Placement, Naming, and Documentation Standards

Everything generated in this repository is one of five artifact types. Each type has a fixed location, naming convention, and documentation requirement. The auto-updating README index (see [Automatic README Updates](#automatic-readme-updates)) depends on these conventions — an artifact that deviates is either missing from the index or listed without a description. Check this table before creating any new file:

| Type | Location | Naming | Required docs | In README index |
|------|----------|--------|---------------|-----------------|
| Composite action | `composite/<action-name>/` | kebab-case directory | `README.md` in the action directory | Yes |
| Reusable workflow | `.github/workflows/` | `<workflow-name>.yml`, kebab-case, no prefix | Sibling `<workflow-name>.md` | Yes |
| Ruleset workflow | `.github/workflows/` | `ruleset-<name>.yml` | Sibling `ruleset-<name>.md` | Yes |
| Agentic workflow | `.github/workflows/` | `agentic-<name>.yml` | Sibling `agentic-<name>.md` | Yes |
| Repo-internal workflow | `.github/workflows/` | `_<name>.yml` (underscore prefix) | None | No (excluded) |

GitHub requires workflow files to live directly in `.github/workflows/` (no subdirectories), so the filename prefix is what distinguishes workflow types. Never place a workflow anywhere else, and never invent new top-level directories for actions or workflows.

### Reusable workflows

Public workflows that other repositories call via `uses: wallentx/gh-actions/.github/workflows/<name>.yml@<ref>`.

- Must declare an `on: workflow_call:` trigger — this is how the README indexer identifies a public reusable workflow. A non-underscore workflow without `workflow_call:` is silently omitted from the index.
- The **first line of the file** must be a one-line comment: `# Description: <single sentence>`. The indexer uses it as the index description.
- Must set a human-readable `name:` — the indexer uses it as the index title.
- Must have a sibling doc with the same basename (`termux-run.yml` → `termux-run.md`). When the sibling doc exists, the index links to it instead of the YAML file.

### Ruleset workflows

Workflows designed to be required by repository or organization rulesets ("Require workflows to pass before merging").

- Name them `ruleset-<purpose>.yml`, with sibling `ruleset-<purpose>.md`.
- Trigger on `pull_request` **and** `merge_group` — required workflows only support `pull_request`, `pull_request_target`, and `merge_group`, and without `merge_group` any repo using a merge queue stalls at "Expected". Do not declare `workflow_call`; it is not a supported ruleset-workflow trigger. The README indexer recognizes the `ruleset-` filename prefix directly.
- Rulesets **ignore all event filters** (`paths`, `branches`, `types`) and run the workflow on every PR in every targeted repo. Do path/content filtering inside the workflow, with a fast short-circuit to success.
- Ruleset workflows execute in each **target repository's** context with that repo's code checked out. Default to `permissions: contents: read` and no secrets (org-level secrets only if unavoidable, consumed before any repo-controlled code runs). Never combine `pull_request_target` with checking out PR head code.
- Do not rely on `concurrency: cancel-in-progress` — it is not honored for ruleset-required runs.
- Ruleset workflows must be **self-contained**: no `uses:` references to mutable refs (no composites or workflows `@main`). Inline the steps, or pin dependencies to a full commit SHA. A ruleset workflow is an org-wide merge gate — its behavior must never change as a side effect of an unrelated merge to this repository. Reference it from rulesets via a **protected ref** (e.g. a `compliance/stable` branch or protected tag that only maintainers can move) rather than `main`: updating the gate is then one deliberate, attributable action — advancing the protected ref — while iteration on `main` stays low-friction. Pointing a ruleset at `main` is acceptable while it is in Evaluate mode.
- Follow the same rules as reusable workflows: `# Description:` comment on the first line, human-readable `name:`, sibling doc.
- The sibling doc must additionally state what the workflow enforces, how to reference it from a ruleset (source repo, workflow path, pinned ref), and rollout guidance (start in Evaluate mode; plan a bypass list for repos where the check cannot run).

### Agentic workflows

Workflows that drive an AI coding agent (e.g. `anthropics/claude-code-action`).

- Shareable agentic workflows are reusable workflows with an `agentic-` prefix: `agentic-<purpose>.yml` with `workflow_call:`, a first-line `# Description:` comment, and sibling `agentic-<purpose>.md`.
- Agent automation that only serves this repository is a repo-internal workflow instead: `_<purpose>.yml`, not indexed.
- The sibling doc must additionally document: which agent action and model is used, required secrets (e.g. `ANTHROPIC_API_KEY`), the `permissions:` the workflow needs, and any guardrails (allowed tools, turn limits, conditions under which the agent will or will not act).

### Repo-internal workflows

Workflows that serve only this repository — CI for the actions themselves, maintenance jobs.

- Always prefix with an underscore: `_<name>.yml`. The underscore is what excludes them from the README index.
- Test workflows follow `_test-<action-name>.yml` (see [Testing and Validation](#testing-and-validation)).
- No sibling doc is required, but still add a short `# Description:` comment on the first line for maintainers.

### Sibling workflow doc format

Every indexed workflow's sibling `.md` follows the same pattern as composite action READMEs so all docs render uniformly:

````markdown
# Workflow Name

## Description

A one-to-two sentence summary, written on a single line.

## Inputs

| Input | Description | Type | Default |
|-------|-------------|------|---------|
| `input-name` | Description | string | `default` |

## Outputs

(Only if the workflow has outputs; add a `## Secrets` table if it takes secrets.)

## Usage

```yaml
jobs:
  example:
    uses: wallentx/gh-actions/.github/workflows/termux-run.yml@main
    with:
      commands: echo "hello from Termux"
```

## Notes
````

The H1 must match the workflow's `name:` field, and the `## Description` body must open with the same sentence as the `# Description:` comment in the YAML so the index and the doc never disagree. See [termux-run.md](.github/workflows/termux-run.md) for a complete example.

## Creating New Composite Actions

When creating a new composite action:

1. **Directory Structure**: Create a new directory under `composite/` with a descriptive kebab-case name (e.g., `my-action`)

2. **Required Files**:
   - `action.yml`: The action definition
   - `README.md`: Comprehensive documentation

3. **action.yml Structure**:
   ```yaml
   name: 'Action Name'
   description: 'Brief description of what this action does'
   inputs:
     input-name:
       description: 'Description of the input'
       required: false
       default: 'default-value'
   outputs:
     output-name:
       description: 'Description of the output'
       value: ${{ steps.step-id.outputs.output-name }}
   runs:
     using: 'composite'
     steps:
       - name: Step name
         id: step-id
         shell: bash
         run: |
           # Shell commands here
           echo "output-name=value" >> $GITHUB_OUTPUT
   ```

4. **README.md Structure**:
   ````markdown
   # Action Name

   ## Description

   A brief, single-sentence description of what this action does, on a single line (see Description rules under Automatic README Updates)

   ## Inputs

   | Input | Description | Required | Default |
   |-------|-------------|----------|---------|
   | `input-name` | Description | No | `default` |

   ## Outputs

   | Output | Description |
   |--------|-------------|
   | `output-name` | Description |

   ## Usage

   ```yaml
   steps:
     - uses: wallentx/gh-actions/composite/checkout-and-cache@main
       with:
         package-manager: 'npm'
   ```
   ````

5. **Start with the Actions Toolbox**: Make [Actions Toolbox](composite/actions-toolbox/) the first step of the new action whenever it needs installed tools or event metadata. Declare dependencies through `include-packages` instead of hand-rolling `apt-get`/curl installers, and consume the environment variables the toolbox publishes (`FILES_CHANGED`, `GH_PR`, `GIT_SHORT_HASH`, `RELEASE`, and more) instead of recomputing them with `git diff`/`gh` lookups. See [Using the Actions Toolbox](#using-the-actions-toolbox) for the full list and a worked example.

6. **Keep shell logic in `scripts/`**: Anything beyond a few lines of shell belongs in a script file, not inline YAML — see [Extracting Long Scripts into `scripts/`](#extracting-long-scripts-into-scripts).

## Coding Standards

### YAML Formatting
- Use 2 spaces for indentation
- Use single quotes for strings unless interpolation is needed
- Add comments for complex logic
- Group related steps together
- Use descriptive names for steps and IDs

### Shell Scripts in Actions
- Always use `set -e` at the start of shell scripts to exit on error
- Use double quotes for variables to handle spaces: `"$VARIABLE"`
- Use `${GITHUB_WORKSPACE}` instead of relative paths
- Add error messages for failure cases
- Use heredocs for multi-line strings

### Extracting Long Scripts into `scripts/`

Keep `run:` blocks in `action.yml` short. When a step's shell commands grow beyond a few lines or contain real logic (loops, conditionals, parsing), move them into a script file — inline YAML scripts are hard to review, aren't linted as shell, and can't be run locally. Follow the pattern used by [actions-toolbox](composite/actions-toolbox/):

- Place scripts in a `scripts/` subdirectory next to the `action.yml`, named in snake_case (e.g. `scripts/run_shellcheck.sh`)
- Start every script with `#!/usr/bin/env bash` and `set -euo pipefail`, followed by a `# Description:` comment block explaining what it does and which environment variables it consumes
- Commit scripts with the executable bit set (`chmod +x`), and invoke them directly from the step:
  ```yaml
  - name: Run ShellCheck
    shell: bash
    env:
      INPUT_SHELLCHECK_GLOBS: ${{ inputs.shellcheck-globs }}
    run: |
      "${GITHUB_ACTION_PATH}/scripts/run_shellcheck.sh"
  ```
- Pass action inputs to the script as `INPUT_<NAME>` environment variables via the step's `env:` block, as shown above. Never reference `${{ }}` expressions inside script files (they are not templated), and avoid interpolating `${{ inputs.* }}` directly into `run:` bodies — routing values through `env:` prevents shell injection from untrusted input
- Use `"${GITHUB_ACTION_PATH}/scripts/..."` to locate scripts — never relative paths, which resolve against the consumer's workspace
- Provide OS-specific variants where needed, following actions-toolbox: `<name>_unix.sh` plus `<name>_windows.ps1`, selected with `if: runner.os` conditions

Reusable workflows cannot ship script files — `GITHUB_ACTION_PATH` does not apply, and this repository is not checked out in the caller's job. Keep reusable workflow logic self-contained, as in [termux-run.yml](.github/workflows/termux-run.yml), or call a composite action pinned to a deliberate ref.

### Input/Output Conventions
- Use kebab-case for input and output names (e.g., `package-manager`)
- Provide sensible defaults for optional inputs
- Document all inputs and outputs in both `action.yml` and `README.md`
- Use descriptive names that clearly indicate purpose

### Documentation Standards
- Every action MUST have a `## Description` section with a single-sentence summary
- Include comprehensive `## Inputs` and `## Outputs` tables
- Provide multiple usage examples covering common scenarios
- Use code blocks with syntax highlighting (```yaml)
- Link to related actions when applicable

## Testing and Validation

### Before Committing
- Test the action in a workflow to ensure it works as expected
- Verify that all inputs and outputs function correctly
- Check that error handling works properly
- Ensure documentation is complete and accurate

### Workflow Testing
Create a repo-internal test workflow in `.github/workflows/_test-<action-name>.yml`:
```yaml
name: Test Action Name
on:
  workflow_dispatch:
  pull_request:
    paths:
      - 'composite/<action-name>/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - name: Test action
        uses: ./composite/<action-name>
        with:
          input-name: 'test-value'
```

### Consumer canary testing

Everything in this repository is consumed `@main`, so a bad merge propagates to every workflow in every consuming repository at once. Before merging a change to a shared composite or reusable workflow, battle-test it against a real consumer:

1. Push your change to a branch in this repository.
2. In a repo that consumes the artifact, open a **draft PR titled `[NO-MERGE] test <actions-repo-branch>`** that switches the consumer's `uses:` ref from `@main` to `@<your-branch>`.
3. Iterate on your branch until the consumer's real workflows pass.
4. Open the PR in this repository, and link the passing Actions run(s) from the canary PR as evidence that the change survives real consumers.
5. Close the `[NO-MERGE]` canary PR without merging.

A green `_test-*.yml` run is necessary but not sufficient — the canary run in a real consumer is what protects `main`.

## Automatic README Updates

The main `README.md` is automatically updated when changes are pushed to the `main` branch (via the [update-md](composite/update-md/) composite action). The update workflow:
- Scans reusable workflows, excluding repo-internal `_*.yml` files
- Scans all composite action directories
- Extracts the title from each action's `README.md`
- Extracts the description from the `## Description` section
- Generates an index with links and descriptions only
- Keeps detailed workflow usage docs in sibling markdown files (e.g. `.github/workflows/<workflow-name>.md`)

### Generated-file rule

`README.md` is generated output. Never edit or regenerate it during feature, fix, documentation, or pull-request work. To change its structure, headings, selection rules, formatting, or other generated content, edit [composite/update-md/action.yml](composite/update-md/action.yml). The `_update-readme.yml` workflow regenerates and commits `README.md` after source changes reach `main`.

Artifact descriptions belong in their source documentation: workflow descriptions in the YAML `# Description:` comment and sibling `.md` file, and composite descriptions in the action's `README.md`. Do not copy those changes into the root `README.md` manually.

### How the indexer extracts titles and descriptions

- **Workflows**: every `.github/workflows/*.yml` without an underscore prefix that either contains a `workflow_call:` trigger or uses the `ruleset-` filename prefix. Title = the `name:` field; description = the first-line `# Description:` comment; link = the sibling `.md` doc when it exists, otherwise the YAML file.
- **Composite actions**: every `composite/*/` directory containing a `README.md`. Title = the first `# ` H1; description = the **first non-blank line** after the `## Description` heading.

### Description rules

These apply to composite `## Description` sections and workflow `# Description:` comments alike:

- One or two sentences, roughly 80–200 characters — long enough to say what the artifact does and when to use it, short enough to scan in the index.
- Must be a **single physical line**. The extractors read exactly one line, so a description wrapped across lines or split into paragraphs is silently truncated in the index.
- Plain prose: no headings, lists, images, or line breaks (inline links and a leading emoji are fine).
- Start with a verb or the artifact's role ("Runs ShellCheck…", "Deploys Grafana dashboards…", "A composite action that…") and end with a period.

**Important**: a missing `## Description` section (composite) or `# Description:` comment (workflow) produces an index entry with no description. A missing `README.md` omits a composite; a public workflow without either `workflow_call:` or a `ruleset-` filename is also omitted. When adding or renaming an artifact, confirm it will be indexed correctly — the conventions in [Placement, Naming, and Documentation Standards](#placement-naming-and-documentation-standards) are exactly what the indexer expects.

## Version Pinning

When using these actions in workflows:
- **For production**: Pin to a specific commit SHA or version tag
- **For development**: Can use `@main` but be aware of potential changes
- **Recommended**: Use semantic version tags (e.g., `@v1`, `@v1.2.3`)

Example:
```yaml
# Most secure - specific commit
- uses: wallentx/gh-actions/composite/checkout-and-cache@abc123

# Recommended - version tag
- uses: wallentx/gh-actions/composite/checkout-and-cache@v1

# Development - latest from main
- uses: wallentx/gh-actions/composite/checkout-and-cache@main
```

## Common Patterns

### Using the Actions Toolbox
Prefer the [Actions Toolbox](composite/actions-toolbox/) (`wallentx/gh-actions/composite/actions-toolbox`) as the first step of new composite actions and workflows. It solves two recurring problems in one place:

1. **Dependency installation** via `include-packages` — system packages (`foo`, `foo=1.2.3`, `command:package`) and tools published as GitHub release binaries (`owner/repo`, `command:owner/repo=version`). Don't hand-roll `apt-get install` steps or curl-pipe installers.
2. **Reusable event metadata** published to `GITHUB_ENV` for every subsequent step in the job — PR context (`GH_PR`, `GH_PR_STATE`, `GH_PR_URL`, `GH_PR_AUTHOR`, `GH_PR_MERGED_AT`), changed files as JSON arrays (`FILES_CHANGED`, `FILES_DELETED`), repo/commit info (`GIT_SHORT_HASH`, `GH_COMMIT_URL`, `GH_DEFAULT_BRANCH`), release/versioning info (`RELEASE`, `PRE_RELEASE`, `GH_LATEST_TAG`, `GH_NEXT_PATCH`), and more.

When writing workflow logic, check whether the toolbox already provides the value before computing it yourself — consume `$FILES_CHANGED` instead of scripting `git diff`, `$GH_PR` / `$GH_PR_STATE` instead of `gh pr view` lookups, `$GIT_SHORT_HASH` instead of `cut`-ing `GITHUB_SHA`. This keeps workflows short and consistent across event types. The toolbox needs `GH_TOKEN` in its `env` for GitHub CLI lookups. See [_test-actions-toolbox.yml](.github/workflows/_test-actions-toolbox.yml) for live usage examples.

### Using GitHub Actions Toolkit
When using actions like `actions/checkout@v7` and `actions/cache@v6`:
- Always specify a version matching the versions already validated in this repository
- Check for the latest version before adding
- Document why specific versions are used if not using latest

### Caching
- Use appropriate cache keys based on lock files
- Include the package manager name in cache key prefix
- Set reasonable cache paths
- Consider cache restore fallback patterns

### Environment Variables
- Use `$GITHUB_OUTPUT` for step outputs (not `::set-output::`)
- Use `$GITHUB_ENV` for environment variables
- Avoid using deprecated `::set-env::` command
- Use `${{ inputs.input-name }}` for accessing inputs

### Error Handling
- Validate inputs at the start of scripts
- Provide clear error messages
- Use conditional logic for optional features
- Exit with appropriate error codes

## Contributing Guidelines

When contributing to this repository:
1. Follow the coding standards and documentation requirements
2. Test your changes thoroughly before submitting
3. Ensure your action works across different operating systems if applicable
4. Add appropriate examples in the README
5. The README index will be automatically updated after merge
6. Keep changes focused and atomic
7. Write clear commit messages describing the change

## Best Practices

1. **Keep Actions Simple**: Each action should do one thing well
2. **Make Actions Composable**: Design actions that can be combined with others
3. **Provide Good Defaults**: Make common use cases work with minimal configuration
4. **Be Defensive**: Validate inputs, handle errors gracefully
5. **Document Everything**: Clear documentation is as important as the code
6. **Test Thoroughly**: Include edge cases and error scenarios
7. **Version Responsibly**: Use semantic versioning for releases
