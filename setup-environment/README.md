# Setup Environment

A composite action to set up common environment variables and tools for GitHub Actions workflows.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `node-version` | Node.js version to setup | No | `20` |
| `cache-dependency-path` | Path to dependency file for caching | No | `package-lock.json` |

## Outputs

| Output | Description |
|--------|-------------|
| `timestamp` | Timestamp when the action was run (UTC) |

## Usage

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Setup environment
    uses: wallentx/gh-actions/setup-environment@main
    with:
      node-version: '20'
      cache-dependency-path: 'package-lock.json'
```

## Example with outputs

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Setup environment
    id: setup
    uses: wallentx/gh-actions/setup-environment@main
    with:
      node-version: '18'
  
  - name: Use timestamp
    run: echo "Setup completed at ${{ steps.setup.outputs.timestamp }}"
```
