#!/bin/bash

: "${GOVC_PASSWORD:? GOVC_PASSWORD must be set }"
: "${GOVC_USERNAME:? GOVC_USERNAME must be set }"
: "${BBL_STATE_DIR:? BBL_STATE_DIR must be set for BUCC to use. See README for details }"

set -euo pipefail

TMPDIR=""
TMPDIR=$(mktemp -d -t deploy_bucc.XXXXXX)
trap 'rm -rf ${TMPDIR}' INT TERM QUIT EXIT

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh
bucc_env_file_to_source="${SCRIPT_DIR}"/bucc_env

# Idempotent approach which is meant to affect first run through to prevent BUCC generating the vars file https://github.com/starkandwayne/bucc/blob/2af7a2b47a151007b4db089f2349aa58bce8d1fc/bin/bucc#L69
mkdir -p "$STATE_VARS_DIR"
touch "$STATE_VARS_FILE"
cat <<EOF > "$STATE_VARS_DIR/flags"
dns
resource-pool
EOF

# prepare ops files by copying over the ones based on if config has been provided
echo "Checking if vcenter_ca_cert needs to be configured. Parsing ${BUCC_INFRA_SETTINGS_FILE} to see if optional field vcenter_ca_cert was added"
if bosh int "${BUCC_INFRA_SETTINGS_FILE}" --path /vcenter_ca_cert ; then
  cp_ops_file_to_state_dir "custom-ca.yml"
else
  echo "No vcenter_ca_cert config found so ignoring. If required add it to the file ${BUCC_INFRA_SETTINGS_FILE}"
fi

cat <<EOF > "${TMPDIR}"/deploy-inputs.yml
vcenter_password: '${GOVC_PASSWORD}'
vcenter_user: '${GOVC_USERNAME}'
EOF

spruce merge "${STATE_ROOT_DIR}"/infra-settings.yml \
        "${TMPDIR}"/deploy-inputs.yml \
        > "${STATE_VARS_FILE}"

bucc_cmd up --cpi vsphere --debug
echo "Deploy completed successfully"
echo "Running test suite against the BUCC installation..."
source <("${bucc_env_file_to_source}")
bucc_cmd test
"${SCRIPT_DIR}"/test_default_concourse_worker_exists.sh
store_bucc_interpolation_result
store_bucc_state_director_vars

echo "[SUCCESS] Phase 1 complete. BUCC installed in its default configuration"
echo "Phase 2: Swapping out internal Concourse worker for a bosh-managed Concourse worker VM"

"${SCRIPT_DIR}"/bosh_deploy_concourse_worker.sh
echo "Will remove internal worker via re-deploy of BUCC if required"
source_ops_file_name="remove-internal-concourse-worker.yml"
cp_ops_file_to_state_dir "${source_ops_file_name}"

bucc_cmd up --cpi vsphere --debug # TODO: Optimise. This is idempotent but not efficient.
echo "Deploy completed successfully"
echo "Running test suite against the BUCC installation..."
source <("${bucc_env_file_to_source}")
bucc_cmd test
"${SCRIPT_DIR}"/test_default_concourse_worker_exists.sh
store_bucc_interpolation_result

echo "[SUCCESS] Phase 2 complete. BUCC configured with external worker VM"



