#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh

: "${BOSH_OPS_FILES_DIR:? BOSH_OPS_FILES_DIR must be set }"
: "${BUCC_INFRA_SETTINGS_FILE:? BUCC_INFRA_SETTINGS_FILE must be set }"
: "${BOSH_MANIFEST_DIR:? BOSH_MANIFEST_DIR must be set }"

"${SCRIPT_DIR}"/bosh_update_cloud_config.sh

echo "Starting bosh deploy process.."
export BOSH_INTERPOLATE_VALIDATION_CREDHUB_VAR_EXCLUSIONS="secret_key access_key"
declare -a flags
bosh_vars_file="${BUCC_INFRA_SETTINGS_FILE}"
flags+=(--vars-file ${bosh_vars_file})

manifest="${BOSH_MANIFEST_DIR}"/minio-deployment.yml
bosh_deploy "${manifest}" minio "${flags[@]}"

echo "Ensure Minio creds and config available for other pipelines"
bucc_cmd credhub > /dev/null
secret_key=$(credhub get -n /$BOSH_ENV_ALIAS/minio/secret_key -q)
 credhub set -n /concourse/main/minio_secret_key -t password -w $secret_key # IMPORTANT BASH TRICK: space at beginning of this line to prevent secret being exposed in history
access_key=$(credhub get -n /$BOSH_ENV_ALIAS/minio/access_key -q)
 credhub set -n /concourse/main/minio_access_key -t password -w $access_key # IMPORTANT BASH TRICK: space at beginning of this line to prevent secret being exposed in history
minio_ip=$(spruce json $bosh_vars_file | jq -r .minio_ip)
credhub set -n /concourse/main/minio_ip -t value -v $minio_ip
credhub set -n /concourse/main/minio_url -t value -v http://$minio_ip:9001
minio_server_region=$(spruce json $bosh_vars_file | jq -r .minio_server_region)
credhub set -n /concourse/main/minio_server_region -t value -v $minio_server_region

