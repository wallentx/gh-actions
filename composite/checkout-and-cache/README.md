# Checkout and Cache

## Description

A composite action that combines repository checkout with intelligent dependency caching for common package managers.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `ref` | The branch, tag or SHA to checkout | No | `''` (default branch) |
| `fetch-depth` | Number of commits to fetch. 0 indicates all history | No | `1` |
| `package-manager` | Package manager to cache (npm, yarn, pnpm, pip, or none) | No | `npm` |
| `cache-path` | Custom path(s) to cache (overrides package-manager setting) | No | `''` |
| `cache-key-prefix` | Prefix for the cache key | No | `deps` |

## Features

- Automatically detects and caches dependencies based on package manager
- Supports npm, yarn, pnpm, and pip
- Uses lock files for cache key generation
- Customizable cache paths and key prefixes
- Displays cache configuration for debugging

## Usage

### Basic Usage (npm)

```yaml
steps:
  - name: Checkout and cache
    uses: wallentx/gh-actions/checkout-and-cache@main
```

### With Yarn

```yaml
steps:
  - name: Checkout and cache
    uses: wallentx/gh-actions/checkout-and-cache@main
    with:
      package-manager: 'yarn'
```

### With Python pip

```yaml
steps:
  - name: Checkout and cache
    uses: wallentx/gh-actions/checkout-and-cache@main
    with:
      package-manager: 'pip'
```

### Checkout Specific Branch

```yaml
steps:
  - name: Checkout and cache
    uses: wallentx/gh-actions/checkout-and-cache@main
    with:
      ref: 'develop'
      fetch-depth: '0'
```

### Custom Cache Path

```yaml
steps:
  - name: Checkout and cache
    uses: wallentx/gh-actions/checkout-and-cache@main
    with:
      package-manager: 'npm'
      cache-path: |
        ~/.npm
        node_modules
```

### Without Caching

```yaml
steps:
  - name: Checkout only
    uses: wallentx/gh-actions/checkout-and-cache@main
    with:
      package-manager: 'none'
```
