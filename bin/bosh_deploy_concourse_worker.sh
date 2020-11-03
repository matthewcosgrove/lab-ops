#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh

: "${BUCC_SUBMODULE_LOCATION:? BUCC_SUBMODULE_LOCATION must be set }"
: "${BOSH_OPS_FILES_DIR:? BOSH_OPS_FILES_DIR must be set }"
: "${STATE_VARS_FILE:? STATE_VARS_FILE must be set }"
: "${BOSH_MANIFEST_DIR:? BOSH_MANIFEST_DIR must be set }"

"${SCRIPT_DIR}"/bosh_update_cloud_config.sh


echo "Starting bosh deploy process.."
export BOSH_INTERPOLATE_VALIDATION_CREDHUB_VAR_EXCLUSIONS="/concourse/main/concourse_worker_key /concourse/main/concourse_tsa_host_key.public_key"
declare -a flags
flags=(-o "${BUCC_SUBMODULE_LOCATION}"/ops/9-concourse-compiled-release.yml) # Re-using BUCC ops files
flags+=(--vars-file $STATE_VARS_FILE)

manifest="${BOSH_MANIFEST_DIR}"/concourse-external-worker-vm-deployment.yml
bosh_deploy "${manifest}" concourse-external-worker "${flags[@]}"

