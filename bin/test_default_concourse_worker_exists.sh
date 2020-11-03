#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh

bucc_cmd fly

echo "[TEST] Default worker should be available"
fly -t "${BOSH_ENV_ALIAS}" workers # Human readable for output
# set +e 
if fly -t "${BOSH_ENV_ALIAS}" workers --json | grep tags | grep -v null; then # grep -v null => filter out default workers => grep returns exit code 1 if none to filter
  echo "[FAILED] No default Concourse workers. BUCC installation cannot work without a default untagged worker" 
  exit 1
else
  echo "[SUCCESS] Default untagged Concourse worker found"
  exit 0
fi

