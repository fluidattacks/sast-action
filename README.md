# Fluid Attacks SAST

Free, open-source static application security testing (SAST) action for your GitHub repositories. No account, API key, or registration required.

## Quick Start (2 minutes)

You only need to do two things to start scanning your code for vulnerabilities:

### 1. Create the configuration file

Add a file called `.fluidattacks.yaml` in the root of your repository:

```yaml
language: EN
strict: false
output:
  file_path: results.sarif
  format: SARIF
sast:
  include:
    - .
```

That's it for configuration. This minimal setup will scan your entire repository.

### 2. Create the GitHub Actions workflow

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
          # Required for differential scanning (default mode).
          # Can be omitted if scanner_mode: full is set.
          fetch-depth: 0

      - uses: fluidattacks/sast-action@1.1.0
        id: scan
```

Commit both files, push, and the scan will run automatically. Results will appear in the **Security** tab of your repository under **Code scanning alerts**.

## Prerequisites

- A GitHub repository (public or private).
- GitHub Actions enabled on the repository.
- No account, token, or API key is needed. The action is 100% open source.

## How it works

### Default branch detection

The action automatically detects your repository's default branch by running `git remote show origin`. This means it works with any branch name — `main`, `master`, `trunk`, `develop`, or whatever your team uses. You don't need to configure the branch name anywhere in `.sast.yaml`.

### Scan types

The action determines the scan type based on context:

| Trigger | Scan type | What it analyzes |
|---|---|---|
| Push to default branch | Full scan | All files in the repository |
| Push to any other branch | Differential scan | Only files changed vs. default branch |
| Pull request | Differential scan | Only files changed vs. PR base branch |

Both differential scan modes compare against the full default branch (not just the previous commit), so even if a push contains multiple commits, all changes relative to the default branch are analyzed. This keeps your CI fast while ensuring nothing slips through.

You can force a full scan on every run with `scanner_mode: full` — see [Action inputs](#action-inputs).

### Why `fetch-depth: 0`?

The `actions/checkout` step uses `fetch-depth: 0` to download the full git history. This is necessary for the differential scan to compare your current changes against the PR base. Without it, the action would not have enough context to determine what changed.

If you set `scanner_mode: full`, the action skips all git comparisons entirely, so a default shallow checkout is sufficient — `fetch-depth: 0` is not needed.

## Viewing results

After the workflow runs, results are written to the path you configured in `output.file_path` (e.g. `results.sarif`).

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

The action looks for configuration in the following order:

1. **`.fluidattacks.yaml`** — primary config file (recommended)
2. **`.sast.yaml`** — legacy config file, used if `.fluidattacks.yaml` is not present
3. **Built-in defaults** — if neither file exists, the action scans the entire repository (`sast.include: [.]`) and writes results to `.fluidattacks-sast-results.sarif`

Place whichever file you use at the root of your repository.

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
  # checks:
  #   - F008   # SQL Injection
  #   - F012   # Cross-Site Scripting
  #   - F021   # Insecure File Upload
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
| `scanner_mode` | No | _(auto)_ | Override the scan mode. `full` forces a full repository scan. If omitted, the mode is determined automatically based on the event and branch. |

### `scanner_mode: full`

Forces a full repository scan regardless of the event. Useful for scheduled audits or when you want every run to cover the entire codebase.

```yaml
- uses: fluidattacks/sast-action@1.1.0
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

### Strict mode: block merges with vulnerabilities

Set `strict: true` to make the action fail when vulnerabilities are found. Combined with branch protection rules, this prevents vulnerable code from being merged:

```yaml
strict: true
```

Then, in your repository settings, enable **Require status checks to pass before merging** and select the SAST check.

### Export results as CSV

If you want a CSV report instead of (or in addition to) SARIF:

```yaml
output:
  file_path: results.csv
  format: CSV
```

Or export both:

```yaml
output:
  file_path: results
  format: ALL
```

This generates both `results.sarif` and `results.csv`.

## Troubleshooting

### The scan runs but no results appear in the Security tab

Make sure the "Upload SARIF" step is included in your workflow and uses `if: always()` so it runs even if the scan finds vulnerabilities with `strict: true`.

### The differential scan analyzes all files instead of just changes

Verify that `fetch-depth: 0` is set in the `actions/checkout` step. Without full git history, the action cannot determine which files changed.

### I don't have a `.fluidattacks.yaml` or `.sast.yaml` file

No config file is required. When neither is present, the action uses built-in defaults: scans the entire repository and writes results to `.fluidattacks-sast-results.sarif`. Add a config file only if you need to customize paths, output format, or other options.

### The action doesn't detect my default branch

The action runs `git remote show origin` to detect the default branch. This requires `fetch-depth: 0` in the checkout step so the remote metadata is available. If detection fails, verify that the `origin` remote is correctly configured in your repository.

### The pipeline fails unexpectedly

If `strict: true` is set, the pipeline will fail whenever vulnerabilities are found. This is intentional. Set `strict: false` if you want the scan to report vulnerabilities without failing the pipeline.

## More information

- [Source code on GitHub](https://github.com/fluidattacks/sast-action)
- [Vulnerability database](https://db.fluidattacks.com)
- [Fluid Attacks documentation](https://docs.fluidattacks.com)
- [SARIF format specification](https://sarifweb.azurewebsites.net/)
