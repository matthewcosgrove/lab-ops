#!/bin/bash

: "${BBL_STATE_DIR:? BBL_STATE_DIR must be set for BUCC to use. See README for details }"

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh

"$SCRIPT_DIR"/deploy_bucc.sh
"$SCRIPT_DIR"/bosh_deploy_minio_s3.sh

echo "TODO: Deploy Promethues"
