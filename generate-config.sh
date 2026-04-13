#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/tmp/sast-config.yaml"
USER_CONFIG="${GITHUB_WORKSPACE}/.sast.yaml"

check_changed_files() {
  if [[ ${INPUT_MODE} == "diff" && -z "${CHANGED_FILES}" ]]; then
    echo "::notice::No files changed. Skipping scan."
    echo "skip=true" >> "${GITHUB_OUTPUT}"
    return 1
  fi
}

prepare_config() {
  if [[ ${INPUT_MODE} == "diff" ]]; then
    python3 -c "
import yaml, os

with open('${USER_CONFIG}') as f:
    cfg = yaml.safe_load(f) or {}

cfg['namespace'] = os.environ['GITHUB_REPOSITORY']
cfg['sast'] = cfg.get('sast') or {}
cfg['sast']['include'] = os.environ['CHANGED_FILES'].split()

with open('${CONFIG_FILE}', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, sort_keys=False)
"
  else
    python3 -c "
import yaml, os

with open('${USER_CONFIG}') as f:
    cfg = yaml.safe_load(f) or {}

cfg['namespace'] = os.environ['GITHUB_REPOSITORY']

with open('${CONFIG_FILE}', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, sort_keys=False)
"
  fi
}

run_scan() {
  echo "::group::Generated configuration"
  cat "${CONFIG_FILE}"
  echo "::endgroup::"

  local exit_code=0
  docker run --rm \
    -v "${GITHUB_WORKSPACE}:/src" \
    -v "${CONFIG_FILE}:${CONFIG_FILE}:ro" \
    "ghcr.io/fluidattacks/sast:latest" \
    sast scan "${CONFIG_FILE}" || exit_code=$?

  if [[ ${exit_code} -eq 0 ]]; then
    echo "vulnerabilities_found=false" >> "${GITHUB_OUTPUT}"
  elif [[ ${exit_code} -eq 1 ]]; then
    echo "vulnerabilities_found=true" >> "${GITHUB_OUTPUT}"
  else
    echo "::error::Scanner exited with code ${exit_code}"
    exit "${exit_code}"
  fi

  python3 -c "
import yaml, re
with open('${CONFIG_FILE}') as f:
    cfg = yaml.safe_load(f)
fmt = cfg.get('output', {}).get('format', '')
if fmt in ('SARIF', 'ALL'):
    path = cfg['output']['file_path']
    sanitized = re.sub(r'[\r\n]', '', str(path))
    print('sarif_file=' + sanitized)
" >> "${GITHUB_OUTPUT}" 2> /dev/null || true
}

main() {
  if ! check_changed_files; then
    exit 0
  fi

  prepare_config
  echo "skip=false" >> "${GITHUB_OUTPUT}"
  run_scan
}

main
