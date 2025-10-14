# gh-actions

A centralized repository for reusable GitHub Actions composite actions. These actions can be referenced from any GitHub Actions workflow in any repository.

## Available Actions

### [checkout-and-cache](./checkout-and-cache/)

Combines repository checkout with intelligent dependency caching for common package managers (npm, yarn, pnpm, pip).

**Quick usage:**
```yaml
- uses: wallentx/gh-actions/checkout-and-cache@main
  with:
    package-manager: 'npm'
```

See [checkout-and-cache/README.md](./checkout-and-cache/README.md) for full documentation.

### [setup-environment](./setup-environment/)

Sets up common environment variables and tools for workflows. Includes Node.js setup with caching and environment information display.

**Quick usage:**
```yaml
- uses: wallentx/gh-actions/setup-environment@main
  with:
    node-version: '20'
```

See [setup-environment/README.md](./setup-environment/README.md) for full documentation.

## How to Use These Actions

### In Your Workflows

Reference any action in this repository using the following format:

```yaml
steps:
  - uses: wallentx/gh-actions/<action-name>@<ref>
```

Where:
- `<action-name>` is the directory name of the action (e.g., `setup-environment`)
- `<ref>` is a git reference (branch, tag, or commit SHA)

### Recommended Versioning

For production workflows, it's recommended to pin to a specific version:

```yaml
# Pin to a specific commit (most secure)
- uses: wallentx/gh-actions/setup-environment@<commit-sha>

# Pin to a version tag (recommended)
- uses: wallentx/gh-actions/setup-environment@v1

# Use the latest from main branch (use with caution)
- uses: wallentx/gh-actions/setup-environment@main
```

## Creating New Actions

To add a new composite action to this repository:

1. Create a new directory with a descriptive name (e.g., `my-action`)
2. Add an `action.yml` file in that directory with your action definition
3. Add a `README.md` file documenting the action's usage
4. Update this main README to list the new action

### Composite Action Structure

```
my-action/
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
    value: ${{ steps.step-id.outputs.output-name }}
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
- Include comprehensive documentation
- Follow GitHub Actions best practices
- Are tested before committing

## License

This repository is available for use in any project.