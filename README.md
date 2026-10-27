# Fluid Attacks SAST

Free, open-source static application security testing (SAST) action for your GitHub repositories. No account, API key, or registration required.

## Quick Start (2 minutes)

### 1. Create the GitHub Actions workflow

Add the file `.github/workflows/sast.yml` to your repository:

```yaml
name: SAST
on:
  push:
  pull_request:
    types: [opened, synchronize, reopened]
  schedule:
    - cron: '0 8 * * 1'  # optional: weekly full scan every Monday at 8am

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          # Required for differential scanning (scanner_mode: diff).
          fetch-depth: 0

      - uses: fluidattacks/sast-action@<version>
        id: scan
        with:
          scanner_mode: diff  # recommended
```

Replace `<version>` with the latest release tag. Check the releases page for the current version and update whenever a new one is published.

> **Recommended: run SAST in diff mode.** `scanner_mode: diff` analyzes only the files changed in each push or pull request, which keeps CI fast and focuses the results on the code under review. It requires `fetch-depth: 0` in the checkout step. Pair it with a periodic full scan (for example, the scheduled run above, which falls back to a full scan automatically) to cover the rest of the codebase.

If you omit `scanner_mode`, the action runs a **full scan** of the entire repository on every run. Without a configuration file, it uses built-in defaults and writes results to `.fluidattacks-sast-results.sarif`.

### 2. (Optional) Add a configuration file

To customize scan paths, output format, or strict mode, create a YAML file anywhere in your repository and pass its path to the action:

```yaml
- uses: fluidattacks/sast-action@<version>
  id: scan
  with:
    scan_config_path: .github/sast-config.yaml
```

See [Configuration reference](#configuration-reference) for the full list of options.

Commit and push. The scan will run automatically on the next push or pull request.

## Prerequisites

- A GitHub repository (public or private).
- GitHub Actions enabled on the repository.
- No account, token, or API key is needed to run the scan. The action is 100% open source. Authentication is optional; see [Authentication](#authentication).

## Authentication

Authenticating attributes the run to your Fluid Attacks group and applies the group's platform policy. Set the `group` input and supply credentials in one of two ways.

### OpenID Connect (recommended)

No secret to store. Grant the job `id-token: write`:

```yaml
permissions:
  id-token: write
  contents: read
jobs:
  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: fluidattacks/sast-action@<version>
        with:
          group: my-group
```

In Fluid Attacks, add a trust for issuer `https://token.actions.githubusercontent.com` with the bound claim `repository` = `my-org/my-repo` and enable it for the group. See the [OIDC federation guide](https://docs.fluidattacks.com/find-fix/use-cli/authentication/oidc-federation).

### Group token

```yaml
- uses: fluidattacks/sast-action@<version>
  with:
    group: my-group
    api_token: ${{ secrets.FLUID_GROUP_TOKEN }}
```

The token takes precedence over OIDC. `api_token` is ignored without `group`.

Authentication is best-effort: if `group` is invalid or no credentials are available (for example, pull requests from forks get neither `id-token` nor secrets), the action logs a warning and runs the scan unauthenticated.

## How it works

### Default branch detection

The action automatically detects your repository's default branch by running `git remote show origin`. This means it works with any branch name — `main`, `master`, `trunk`, `develop`, or whatever your team uses. You don't need to configure the branch name anywhere.

### Scan modes

The action supports two scan modes, selected with `scanner_mode`:

| `scanner_mode` | Scan type | What it analyzes |
|---|---|---|
| `diff` (**recommended**) | Differential scan | Only files changed since the base (see below) |
| `full` (default when omitted) | Full scan | All files in the repository |

In `diff` mode, the base depends on the trigger:

| Trigger | Base for comparison |
|---|---|
| Pull request | PR base branch |
| Push to the default branch | Commit before the push (`github.event.before`) |
| Push to any other branch | Default branch (all changes since it, even across multiple commits) |
| Any other event (scheduled, manual, ...) | No base: falls back to a full scan |

If no base commit is available (for example, the first push of a new branch), the action also falls back to a full scan.

We recommend `diff` for push and pull request workflows: it keeps your CI fast while ensuring nothing slips through. Use `full` (or a scheduled run) for periodic audits. See [Action inputs](#action-inputs).

### Why `fetch-depth: 0`?

The `actions/checkout` step needs `fetch-depth: 0` to download the full git history when you use `scanner_mode: diff`. This is necessary to compare your current changes against the base. Without it, the action would not have enough context to determine what changed.

In the default full mode, the action skips all git comparisons entirely, so a default shallow checkout is sufficient.

## Viewing results

After the workflow runs, results are written to the path configured in `output.file_path` (e.g. `results.sarif`), or to `.fluidattacks-sast-results.sarif` when no configuration file is provided.

### SARIF file

The raw SARIF file is always available in your workspace. You can download it as an artifact, process it with other tools, or upload it to a third-party platform.

### GitHub Security tab (optional)

You can upload the SARIF file to GitHub's Security tab so findings appear as **Code scanning alerts** with inline PR annotations:

```yaml
- name: Upload results to GitHub Security tab
  if: always()
  uses: github/codeql-action/upload-sarif@v4
  with:
    sarif_file: ${{ steps.scan.outputs.sarif_file }}
```

> **Restrictions:** SARIF upload to the Security tab requires **GitHub Advanced Security**, which is available on all public repositories and on private repositories under a GitHub Advanced Security license. On private repositories without that license, the upload step will fail. See [GitHub's documentation](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github) for details.

## Configuration reference

When `scan_config_path` is provided, the action uses that file exclusively. When omitted, the action runs with built-in defaults: scans the entire repository (`sast.include: [.]`) or only modified files (depending on the `scanner_mode` selected), and writes results to `.fluidattacks-sast-results.sarif`.

### Minimal configuration

```yaml
language: EN
strict: false
output:
  file_path: results.sarif
  format: SARIF
sast:
  include:
    - .
  exclude:
    - test/
```

### Full configuration example

```yaml
# Language for vulnerability descriptions: EN or ES
language: EN

# If true, the pipeline fails when vulnerabilities are found
# Set to true for stricter enforcement
strict: false

output:
  # Path where the results file will be written
  file_path: results.sarif
  # Format: SARIF, CSV, or ALL
  format: SARIF

sast:
  # Paths to include in the scan (relative to repo root)
  include:
    - src/
    - lib/

  # Paths to exclude from the scan
  exclude:
    - src/vendor/
    - "**/*.test.js"

# Specific checks to enable (omit to run all checks)
checks:
  - F008   # Remote command execution
  - F027   # Insecure File Upload
```

### Configuration options

| Option | Required | Default | Description |
|---|---|---|---|
| `language` | No | `EN` | Language for descriptions (`EN` or `ES`) |
| `strict` | No | `false` | Fail the pipeline if vulnerabilities are found |
| `output.file_path` | No | `.fluidattacks-sast-results.sarif` | Path for the output file |
| `output.format` | No | `SARIF` | Output format: `SARIF`, `CSV`, or `ALL` |
| `sast.include` | No | `[.]` | List of paths to scan |
| `sast.exclude` | No | — | List of paths to exclude |
| `checks` | No | All | List of specific [checks](https://db.fluidattacks.com/wek/) to run |

## Action inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `scan_config_path` | No | — | Path to the YAML configuration file, relative to the repository root. When omitted, the action runs with built-in defaults. The job fails if the file does not exist at the given path. |
| `scanner_mode` | No | `full` | Scan mode. `diff` (**recommended**) scans only changed files versus the base branch or PR base. `full` scans the entire repository (default). |

### `scan_config_path`

Point the action at your configuration file:

```yaml
- uses: fluidattacks/sast-action@<version>
  id: scan
  with:
    scan_config_path: .github/sast-config.yaml
```

The path is relative to the repository root. The job fails immediately if the file does not exist.

### `scanner_mode: diff` (recommended)

Scans only the files changed relative to the base (see [Scan modes](#scan-modes)). This is the recommended way to run SAST on pushes and pull requests. Requires `fetch-depth: 0` in the checkout step so the action can compare git history.

Diff mode is only active on `push` and `pull_request` events. For any other event (e.g. `schedule`, `workflow_dispatch`), the action automatically falls back to a full scan.

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0

- uses: fluidattacks/sast-action@<version>
  id: scan
  with:
    scanner_mode: diff
```

### `scanner_mode: full`

The default. Scans the entire repository regardless of the event. Useful for scheduled audits or when you want every run to cover the entire codebase. No `fetch-depth: 0` needed.

```yaml
- uses: fluidattacks/sast-action@<version>
  id: scan
  with:
    scanner_mode: full
```

## Action outputs

| Output | Description |
|---|---|
| `sarif_file` | Path to the SARIF results file (when format is `SARIF` or `ALL`) |
| `vulnerabilities_found` | `true` if any vulnerabilities were detected, `false` otherwise |

You can use these outputs in subsequent workflow steps. For example, to add a conditional step:

```yaml
- name: Comment on PR
  if: steps.scan.outputs.vulnerabilities_found == 'true'
  run: echo "Vulnerabilities were found. Check the Security tab for details."
```

## Common scenarios

### Monorepo: scan only specific folders

If your repository contains multiple projects, you can limit the scan to specific directories:

```yaml
sast:
  include:
    - services/api/
    - services/web/
  exclude:
    - services/legacy/
```

The included paths are only used in full scans.
In diff scans, all modified files are scanned.

### Strict mode: block merges with vulnerabilities

Set `strict: true` in your configuration file and enable **Require status checks to pass before merging** in your repository's branch protection settings. This prevents vulnerable code from being merged:

```yaml
strict: true
```

### Export results as CSV

If you want a CSV report instead of (or in addition to) SARIF:

```yaml
output:
  file_path: results.csv
  format: CSV
```

## Troubleshooting

### The scan runs but no results appear in the Security tab

Make sure the "Upload SARIF" step is included in your workflow and uses `if: always()` so it runs even if the scan finds vulnerabilities with `strict: true`.

### The differential scan analyzes all files instead of just changes

Verify that `fetch-depth: 0` is set in the `actions/checkout` step and that `scanner_mode: diff` is configured. Without full git history, the action cannot determine which files changed.

### The action doesn't detect my default branch

The action runs `git remote show origin` to detect the default branch. This requires `fetch-depth: 0` in the checkout step so the remote metadata is available. If detection fails, verify that the `origin` remote is correctly configured in your repository.

### The pipeline fails unexpectedly

If `strict: true` is set in your configuration file, the pipeline will fail whenever vulnerabilities are found. This is intentional. Set `strict: false` if you want the scan to report vulnerabilities without failing the pipeline.

### The job fails with "not found in repository"

The path provided to `scan_config_path` does not exist in the repository. Verify the path is correct and relative to the repository root.

## More information

- [Source code on GitHub](https://github.com/fluidattacks/sast-action)
- [Vulnerability database](https://db.fluidattacks.com)
- [Fluid Attacks documentation](https://docs.fluidattacks.com)
- [SARIF format specification](https://sarifweb.azurewebsites.net/)
