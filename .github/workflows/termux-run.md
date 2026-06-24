# Termux Run

`.github/workflows/termux-run.yml` runs arbitrary commands inside a Termux pacman Docker environment on GitHub's hosted ARM runner. It is intended for public repositories that need a free ARM64 Termux execution environment without maintaining their own Termux Docker wrapper script.

## Usage

```yaml
jobs:
  termux:
    uses: wallentx/gh-actions/.github/workflows/termux-run.yml@main
    with:
      packages: |
        clang
      copy-paths: |
        README.md
      env: |
        TERMUX_RUN_MODE=ci
      commands: |
        set -Eeuo pipefail
        test "$TERMUX_RUN_MODE" = "ci"
        clang --version
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `packages` | Newline or whitespace separated pacman packages to install before running commands | No | `""` |
| `copy-paths` | Newline separated files or directories copied into the Termux workspace | No | `.` |
| `exclude-paths` | Newline separated tar exclude patterns omitted while staging files | No | `.git`, `./.git` |
| `env` | Newline separated `KEY=value` entries exported for host prep and inside Termux | No | `""` |
| `host-commands` | Bash commands run on the ARM Ubuntu host before staging files | No | `""` |
| `commands` | Bash commands run inside Termux | Yes | N/A |
| `sync-back-paths` | Newline separated files or directories copied back into the GitHub workspace | No | `""` |
| `upload-artifact-name` | Artifact name used to upload synced paths | No | `""` |
| `termux-image` | Docker image that provides the Termux pacman environment | No | `termux/termux-docker-pacman` |
| `runs-on` | GitHub-hosted runner label | No | `ubuntu-24.04-arm` |
| `checkout` | Whether to run `actions/checkout` for the caller repository | No | `true` |
| `default-packages` | Whether to install default packages such as `termux-exec` | No | `true` |
| `upgrade-system` | Whether to run a full `pacman -Syu` before installing packages | No | `false` |
| `pacman-timeout-minutes` | Timeout for each pacman transaction | No | `10` |

## Copy And Sync Model

The workflow stages only `copy-paths` into a clean Termux workspace under `${PREFIX:-/data/data/com.termux/files/usr}/tmp/ci-workspace`. Use `exclude-paths` to omit generated directories such as `target`, `bin`, or `staging` when copying a broad path like `.`.

Use `host-commands` for downloads or artifact preparation that should happen on the Ubuntu ARM host before staging. Values from the `env` input are exported before `host-commands` run and again inside Termux. Use `sync-back-paths` when commands produce files that later workflow jobs need. If `upload-artifact-name` is set, synced files are also uploaded with `actions/upload-artifact`.

The workflow refreshes pacman package databases before installing requested packages, but it does not run a full base-image upgrade by default. Set `upgrade-system: true` only when the caller explicitly needs `pacman -Syu` before package installation. Each pacman transaction is bounded by `pacman-timeout-minutes`, so post-transaction hook hangs fail the job instead of consuming the whole runner timeout.

Host preparation commands receive `GH_TOKEN` and `GITHUB_TOKEN` from the workflow token. To use a different token, pass the optional `github-token` secret.

Set caller job permissions for whatever `host-commands` need. For example, current-repository release downloads usually need `contents: read`; Actions artifact downloads usually need `actions: read`; uploading artifacts via `upload-artifact-name` usually needs `actions: write`.

## Artifact Smoke Example

```yaml
jobs:
  termux-artifact-smoke:
    permissions:
      contents: read
    uses: wallentx/gh-actions/.github/workflows/termux-run.yml@main
    with:
      packages: |
        ca-certificates
        libc++
        tar
        zstd
      env: |
        RELEASE_TAG=rust-v0.0.0-termux
      host-commands: |
        mkdir -p artifact
        gh release download "$RELEASE_TAG" --pattern '*aarch64-linux-android*.tar.gz' --dir artifact
      copy-paths: |
        artifact
      commands: |
        set -Eeuo pipefail
        archive="$(find artifact -type f -name '*aarch64-linux-android*.tar.gz' -print -quit)"
        test -n "$archive"
        mkdir -p smoke
        tar -xzf "$archive" -C smoke
        find smoke -maxdepth 3 -type f -print
```

## PR Check Matrix Example

```yaml
jobs:
  termux:
    strategy:
      matrix:
        include:
          - packages: clang
            commands: |
              clang --version
              clang-format --version
          - packages: cppcheck
            commands: |
              cppcheck --version
    uses: wallentx/gh-actions/.github/workflows/termux-run.yml@main
    with:
      packages: ${{ matrix.packages }}
      copy-paths: |
        lib
      commands: |
        set -Eeuo pipefail
        ${{ matrix.commands }}
```
