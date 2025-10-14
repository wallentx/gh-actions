# gh-actions

A centralized repository for reusable GitHub Actions composite actions. These actions can be referenced from any GitHub Actions workflow in any repository.

## Composite Actions Index
- 📂 __composite__
   - 📄 [Checkout and Cache](./composite/checkout-and-cache/)
      - _A composite action that combines repository checkout with intelligent dependency caching for common package managers._
   - 📄 [Setup Environment](./composite/setup-environment/)
      - _A composite action to set up common environment variables and tools for GitHub Actions workflows._
   - 📄 [Update Markdown Index](./composite/update-md/)
      - _Automatically generates and updates a table of contents in README.md based on composite actions._



## How to Use These Actions

### In Your Workflows

Reference any action in this repository using the following format:

```yaml
steps:
  - uses: wallentx/gh-actions/composite/<action-name>@<ref>
```

Where:
- `<action-name>` is the directory name of the action (e.g., `setup-environment`)
- `<ref>` is a git reference (branch, tag, or commit SHA)

### Recommended Versioning

For production workflows, it's recommended to pin to a specific version:

```yaml
# Pin to a specific commit (most secure)
- uses: wallentx/gh-actions/composite/setup-environment@<commit-sha>

# Pin to a version tag (recommended)
- uses: wallentx/gh-actions/composite/setup-environment@v1

# Use the latest from main branch (use with caution)
- uses: wallentx/gh-actions/composite/setup-environment@main
```

## Creating New Actions

To add a new composite action to this repository:

1. Create a new directory under `composite/` with a descriptive name (e.g., `my-action`)
2. Add an `action.yml` file in that directory with your action definition
3. Add a `README.md` file documenting the action's usage following the standard format:
   ```markdown
   # Action Name
   
   ## Description
   
   A brief, single-sentence description of what this action does
   
   ## Inputs
   ...
   ```
4. The README index will be automatically updated when changes are pushed

### Composite Action Structure

```
composite/my-action/
├── action.yml    # Action definition with inputs, outputs, and steps
└── README.md     # Documentation for the action
```

### Example action.yml

```yaml
name: 'My Action'
description: 'Description of what this action does'
inputs:
  my-input:
    description: 'Description of the input'
    required: false
    default: 'default-value'
outputs:
  my-output:
    description: 'Description of the output'
    value: 
runs:
  using: 'composite'
  steps:
    - name: Run a command
      id: step-id
      shell: bash
      run: |
        echo "output-name=value" >> $GITHUB_OUTPUT
```

## Benefits of Centralized Actions

- **Consistency**: Standardize workflows across all repositories
- **Maintainability**: Update actions in one place, benefit everywhere
- **Reusability**: Share common functionality across projects
- **Version Control**: Track changes and pin to specific versions

## Contributing

When adding new actions, ensure they:
- Have clear, descriptive names
- Include comprehensive documentation with a `## Description` section
- Follow GitHub Actions best practices
- Are tested before committing

## License

This repository is available for use in any project.
