#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh

declare -a flags
flags=(--vars-file $STATE_VARS_FILE)

bosh_update_cloud_config "${BOSH_MANIFEST_DIR}"/cloud-config.yml "${flags[@]}"
