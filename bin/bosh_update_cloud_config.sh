#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh

TMPDIR=""
TMPDIR=$(mktemp -d -t tmp_vars.XXXXXX)
trap 'rm -rf ${TMPDIR}' INT TERM QUIT EXIT
export BUCC_EXTRA_VARS_YAML_FILE="${BBL_STATE_DIR}"/../bucc-extra-vars.yml
export TMP_VARS_YAML_FILE="${TMPDIR}/vars.yml"
if [ -f $BUCC_EXTRA_VARS_YAML_FILE ];then
  echo "Extra vars to be processed from $BUCC_EXTRA_VARS_YAML_FILE"
  spruce merge "${STATE_VARS_FILE}" "${BUCC_EXTRA_VARS_YAML_FILE}" > "${TMP_VARS_YAML_FILE}"
else
  spruce merge "${STATE_VARS_FILE}" > "${TMP_VARS_YAML_FILE}"
fi

declare -a flags
flags=(--vars-file $TMP_VARS_YAML_FILE)

if [ -f "${STATE_ROOT_DIR}"/cloud-config.yml ];then
  preferred_cloud_config_yaml="${STATE_ROOT_DIR}"/cloud-config.yml
else
  preferred_cloud_config_yaml="${BOSH_MANIFEST_DIR}"/cloud-config.yml
fi
echo "IMPORTANT: Using cloud-config yaml ${preferred_cloud_config_yaml}"
bosh_update_cloud_config "$preferred_cloud_config_yaml" "${flags[@]}"
echo "If you don't see a diff above then nothing has changed in the cloud-config"
