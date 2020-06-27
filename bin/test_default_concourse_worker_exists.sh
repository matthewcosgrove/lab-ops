#!/bin/bash

set -euo pipefail
REPO_ROOT_DIR="$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )")"
"$REPO_ROOT_DIR/src/bucc/bin/bucc" fly

bosh_env_alias=$(bosh int "$REPO_ROOT_DIR/../lab-ops-state/infra-settings.yml" --path /alias)

echo "Test default worker"
set +e # relying on exit code for next line, so making sure set accordingly
if fly -t "$bosh_env_alias" workers --json | grep tags | grep -v null; then # grep -v null => filter out default workers => grep returns exit code 1 if none to filter
  echo "[FAILED] No default workers" 
  exit 1
else
  echo "[SUCCESS] Default worker found"
  exit 0
fi

