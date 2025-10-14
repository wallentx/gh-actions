# Update Markdown Index

## Description

Automatically generates and updates a table of contents in README.md based on composite actions.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `composite-dir` | Directory containing composite actions | No | `composite` |
| `readme-path` | Path to the README.md file to update | No | `README.md` |

## Features

- Automatically scans the composite actions directory
- Extracts descriptions from each action's README.md (from `## Description` section)
- Generates a formatted index with links to each action
- Updates the main README.md with the generated content
- Preserves documentation structure and formatting

## Usage

### Basic Usage

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Update README index
    uses: wallentx/gh-actions/composite/update-md@main
```

### Custom Directories

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Update README index
    uses: wallentx/gh-actions/composite/update-md@main
    with:
      composite-dir: 'actions'
      readme-path: 'docs/README.md'
```

## Requirements

Each composite action's README.md must follow this format:

```markdown
# Action Name

## Description

A brief, single-sentence description of what this action does

## Inputs
...
```

The script will extract the first line after the `## Description` heading to use in the index.
