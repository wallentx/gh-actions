# Update Markdown Index

## Description

Automatically generates and updates README.md indexes for reusable workflows and composite actions.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `workflow-dir` | Directory containing reusable workflows | No | `.github/workflows` |
| `composite-dir` | Directory containing composite actions | No | `composite` |
| `readme-path` | Path to the README.md file to update | No | `README.md` |

## Features

- Automatically scans for public `workflow_call` workflows and `ruleset-*.yml` ruleset workflows
- Skips repo-internal workflows whose filenames start with `_`
- Automatically scans the composite actions directory
- Extracts workflow summaries from `# Description:` comments
- Links workflows to a sibling `.md` file when one exists
- Extracts descriptions from each action's README.md (from `## Description` section)
- Generates a file tree format with emojis (📂 for directories, 📄 for files)
- Displays descriptions in italics under each action
- Replaces the target README.md with an index-only document

## Usage

### Basic Usage

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Update README index
    uses: wallentx/gh-actions/composite/update-md@main
```

### Explicit Paths

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Update README index
    uses: wallentx/gh-actions/composite/update-md@main
    with:
      workflow-dir: '.github/workflows'
      composite-dir: 'composite'
      readme-path: 'README.md'
```

## Requirements

Reusable workflows must use `workflow_call`. Ruleset-required workflows must use a `ruleset-` filename and GitHub-supported ruleset triggers such as `pull_request` and `merge_group`. Both may include a top-level description comment.

```yaml
# Description: Run arbitrary commands in a reusable environment.
name: Example Reusable Workflow

on:
  workflow_call:
    inputs:
      commands:
        required: true
        type: string
```

Each composite action's README.md must follow this format:

```markdown
# Action Name

## Description

A brief, single-sentence description of what this action does

## Inputs
...
```

The script will extract the first line after the `## Description` heading to use in the index.

## Output Format

The generated indexes will be formatted as file trees with emojis:

```markdown
## Workflows Index
- 📂 __.github/workflows__
   - 📄 [Example Reusable Workflow](./.github/workflows/example.md)
      - _Run arbitrary commands in a reusable environment._

## Composite Actions Index
- 📂 __composite__
   - 📄 [Action Name](./composite/action-name/)
      - _Brief description of the action_
   - 📄 [Another Action](./composite/another-action/)
      - _Another brief description_
```
