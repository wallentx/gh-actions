# gh-actions

A centralized repository for reusable GitHub Actions workflows and composite actions. These actions and workflows can be referenced from any GitHub Actions workflow in any repository.

## Workflows Index
- 📂 __.github/workflows__
   - 📄 [All PR checks must pass](./.github/workflows/ruleset-require-all-checks.md)
      - _Waits for every other pull request or merge-group check, then succeeds when each passes or is skipped._
   - 📄 [Termux Run](./.github/workflows/termux-run.md)
      - _Run arbitrary commands inside a Termux pacman Docker environment on GitHub's hosted ARM runner._

## Composite Actions Index
- 📂 __composite__
   - 📄 [Actions Toolbox](./composite/actions-toolbox/)
      - _🧰 Actions Toolbox is a composite GitHub Action designed to help with debugging, diagnostics, and tool management across various operating systems (Linux, macOS, Windows) in GitHub workflows. It performs tasks such as installing packages and tooling, identifying hardware specifications, identifying release/pre-release conditions, dumping contextual information, and setting or printing environment variables that can be used in subsequent steps, and providing rich environment and execution details for diagnostic purposes._
   - 📄 [Checkout and Cache](./composite/checkout-and-cache/)
      - _A composite action that combines repository checkout with intelligent dependency caching for common package managers._
   - 📄 [Require all PR checks](./composite/require-all-checks/)
      - _Waits for every other pull request or merge-group check, then succeeds when each passes or is skipped._
   - 📄 [Update Markdown Index](./composite/update-md/)
      - _Automatically generates and updates README.md indexes for reusable workflows and composite actions._
