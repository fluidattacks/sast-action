# Fluid Attacks SAST Action

Static application security testing (SAST) GitHub Action powered by [Fluid Attacks](https://fluidattacks.com/) scanner.

Automatically scans your codebase for security vulnerabilities on every push and pull request.

## Quick start

1. Create `.sast.yaml` in your repository root:

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

2. Add the workflow to `.github/workflows/sast.yml`:

```yaml
name: SAST
on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: fluidattacks/sast-action@1.0.0
        id: scan

      - name: Upload SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: ${{ steps.scan.outputs.sarif_file }}
```

That's it. No inputs required.

## How it works

The scan mode is determined automatically by the GitHub event that triggers the workflow:

- **Push events** → **Full scan**: analyzes all paths defined in `sast.include`.
- **Pull request events** → **Differential scan**: ignores `sast.include` and only analyzes the files changed in the PR.

### Workflow examples

**Full scan on push to main + differential scan on PRs** (recommended):

```yaml
on:
  push:
    branches: [main]
  pull_request:
```

**Only differential scan on PRs:**

```yaml
on: [pull_request]
```

**Only full scan on every push:**

```yaml
on: [push]
```

## Configuration

All settings go in `.sast.yaml`:

```yaml
# Report language: EN or ES
language: EN

# Fail the pipeline if vulnerabilities are found
strict: true

# Output settings
output:
  file_path: results.sarif
  format: SARIF  # SARIF, CSV, or ALL

# Scan scope
sast:
  include:
    - src/
    - lib/
  exclude:
    - node_modules
    - vendor
    - "**/*.test.js"

# Specific checks to run (empty = all)
checks:
  - F034
  - F143
  - F021
```

## Outputs

| Output | Description |
|---|---|
| `sarif_file` | Path to the SARIF results file (if SARIF format selected) |
| `vulnerabilities_found` | `true` or `false` |

## License

MIT
