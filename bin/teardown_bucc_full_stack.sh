#!/bin/bash

: "${GOVC_PASSWORD:? GOVC_PASSWORD must be set }"
: "${GOVC_USERNAME:? GOVC_USERNAME must be set }"
: "${BBL_STATE_DIR:? BBL_STATE_DIR must be set for BUCC to use. See README for details }"

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh
echo "Ensuring all bosh deployments are removed"
bosh_delete_all_deployments
echo "BUCC's goin' down.."
bucc_cmd down
set -x
rm -rf "${STATE_VARS_DIR}"
rm "${STATE_OPS_FILES_DIR}"/"${STATE_OPS_FILE_PREFIX}"*
set +x
echo "[SUCCESS] Destruction complete"
