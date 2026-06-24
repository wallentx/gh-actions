# GitHub Copilot Instructions for gh-actions Repository

## Project Overview

This repository contains reusable GitHub Actions workflows and composite actions that can be referenced from any GitHub Actions workflow in any repository. The primary goal is to provide standardized, well-documented, and maintainable automation that promotes consistency across multiple projects.

**Key Principles:**
- Consistency: Standardize workflows across all repositories
- Maintainability: Update actions in one place, benefit everywhere
- Reusability: Share common functionality across projects
- Version Control: Track changes and pin to specific versions

## Repository Structure

```
.
├── .github/
│   ├── workflows/
│   │   ├── termux-run.yml       # Public reusable workflow
│   │   ├── termux-run.md        # Public reusable workflow docs
│   │   ├── _test-*.yml          # Repo-internal test workflows
│   │   └── _update-readme.yml   # Repo-internal README index updater
│   └── copilot-instructions.md  # This file
├── composite/                    # All composite actions
│   ├── checkout-and-cache/
│   │   ├── action.yml
│   │   └── README.md
│   ├── setup-environment/
│   │   ├── action.yml
│   │   └── README.md
│   └── update-md/
│       ├── action.yml
│       └── README.md
└── README.md                     # Main repository documentation
```

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
   ```markdown
   # Action Name
   
   ## Description
   
   A brief, single-sentence description of what this action does
   
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
     - uses: wallentx/gh-actions/composite/action-name@main
       with:
         input-name: 'value'
   ```
   ```

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
      - uses: actions/checkout@v4
      - name: Test action
        uses: ./composite/<action-name>
        with:
          input-name: 'test-value'
```

## Automatic README Updates

The main `README.md` is automatically updated when changes are pushed to the `main` branch. The update workflow:
- Scans reusable workflows, excluding repo-internal `_*.yml` files
- Scans all composite action directories
- Extracts the title from each action's `README.md`
- Extracts the description from the `## Description` section
- Generates an index with links and descriptions only
- Keeps detailed workflow usage docs in sibling markdown files such as `.github/workflows/termux-run.md`

**Important**: Ensure your action's `README.md` follows the standard format with a proper `## Description` section for the automatic index to work correctly.

## Version Pinning

When using these actions in workflows:
- **For production**: Pin to a specific commit SHA or version tag
- **For development**: Can use `@main` but be aware of potential changes
- **Recommended**: Use semantic version tags (e.g., `@v1`, `@v1.2.3`)

Example:
```yaml
# Most secure - specific commit
- uses: wallentx/gh-actions/composite/setup-environment@abc123

# Recommended - version tag
- uses: wallentx/gh-actions/composite/setup-environment@v1

# Development - latest from main
- uses: wallentx/gh-actions/composite/setup-environment@main
```

## Common Patterns

### Using GitHub Actions Toolkit
When using actions like `actions/checkout@v4`, `actions/cache@v4`, etc.:
- Always specify a version (preferably using `@v4` format)
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
