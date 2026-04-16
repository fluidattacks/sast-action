#!/usr/bin/env bash
set -euo pipefail

out() { echo "$1" >> "${GITHUB_OUTPUT}"; }

if [[ ! -f ".sast.yaml" ]]; then
  echo "::error::Config file .sast.yaml not found in repository root."
  exit 1
fi

# Explicit full override
if [[ "${SCANNER_MODE}" == "full" ]]; then
  out "mode=full"
  exit 0
fi

# Pull request: diff against PR base
if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
  out "mode=diff"
  out "base_sha=${PR_BASE_SHA}"
  exit 0
fi

DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
CURRENT_BRANCH="${GITHUB_REF#refs/heads/}"

# Default branch: full scan
if [[ "${CURRENT_BRANCH}" == "${DEFAULT_BRANCH}" ]]; then
  out "mode=full"
  exit 0
fi

# Any other branch: diff against default branch
out "mode=diff"
out "base_sha=origin/${DEFAULT_BRANCH}"
