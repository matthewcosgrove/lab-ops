#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh

: "${BUCC_SUBMODULE_LOCATION:? BUCC_SUBMODULE_LOCATION must be set }"
: "${BOSH_OPS_FILES_DIR:? BOSH_OPS_FILES_DIR must be set }"
: "${BUCC_INFRA_SETTINGS_FILE:? BUCC_INFRA_SETTINGS_FILE must be set }"
: "${BOSH_MANIFEST_DIR:? BOSH_MANIFEST_DIR must be set }"

"${SCRIPT_DIR}"/bosh_update_cloud_config.sh


echo "Starting bosh deploy process.."
export BOSH_INTERPOLATE_VALIDATION_CREDHUB_VAR_EXCLUSIONS="/concourse/main/concourse_worker_key /concourse/main/concourse_tsa_host_key.public_key"
declare -a flags
flags=(-o "${BUCC_SUBMODULE_LOCATION}"/ops/3-concourse-release.yml) # Re-using BUCC ops files
flags+=(--vars-file $BUCC_INFRA_SETTINGS_FILE)

manifest="${BOSH_MANIFEST_DIR}"/concourse-external-worker-vm-deployment.yml
bosh_deploy "${manifest}" concourse-external-worker "${flags[@]}"

