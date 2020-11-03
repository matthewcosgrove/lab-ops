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
export BUCC_VCENTER_CA_CERT_YAML_FILE="${BBL_STATE_DIR}"/vcenter-ca-cert.yml
echo "Checking if vcenter_ca_cert needs to be configured by checking for file ${BUCC_VCENTER_CA_CERT_YAML_FILE}" 
if [ -f $BUCC_VCENTER_CA_CERT_YAML_FILE ];then
  if bosh int "${BUCC_VCENTER_CA_CERT_YAML_FILE}" --path /vcenter_ca_cert ; then
    cp_ops_file_to_state_dir "custom-ca.yml"
  else
    echo "No vcenter_ca_cert config found so ignoring. If required add it to the file ${BUCC_VCENTER_CA_CERT_YAML_FILE}. See vcenter-ca-cert-template.yml"
  fi
else
 echo "No vcenter_ca_cert config found so ignoring. If required add it to the file ${BUCC_VCENTER_CA_CERT_YAML_FILE}. See vcenter-ca-cert-template.yml"
fi

echo "Merging in env vars into state yaml file"
cat <<'EOF' > "${TMPDIR}"/deploy-inputs.yml
vcenter_password: (( grab $GOVC_PASSWORD ))
vcenter_user: (( grab $GOVC_USERNAME ))

director_name: (( grab $BOSH_ENV_ALIAS ))
alias: (( grab $BOSH_ENV_ALIAS ))
internal_cidr: (( grab $BUCC_VM_CIDR ))
internal_gw: (( grab $BUCC_VM_GATEWAY ))
internal_ip: (( grab $BUCC_VM_IP ))
network_name: (( grab $GOVC_NETWORK ))
vcenter_cluster: (( grab $GOVC_CLUSTER ))
vcenter_dc: (( grab $GOVC_DATACENTER ))
vcenter_disks: bucc-disks # Recommended not to change, or bosh might not be able to locate the disk on a re-deploy
vcenter_ds: (( grab $BUCC_BOSH_VCENTER_DATASTORE_PATTERN ))
vcenter_ip: (( grab $GOVC_URL ))
vcenter_templates: (( grab vcenter_vms ))
vcenter_vms: (( grab $VCENTER_FOLDER_NAME_RELATIVE_PATH ))
vcenter_vm_cpu: 4
vcenter_vm_disk: 200000
vcenter_vm_ram: 16640

# flag: --dns
vcenter_dns: (( grab $BUCC_BOSH_VCENTER_DNS ))

# flag: --resource-pool
vcenter_rp: (( grab $VCENTER_RESOURCE_POOL_NAME ))

# minio deployment
minio_server_region: bucc-minio

# bosh cloud-config
minio_ip: (( grab $BUCC_BOSH_STATIC_IP_MINIO ))
vcenter_datastore_names: (( grab $BUCC_BOSH_VCENTER_DATASTORE_NAMES_YAML_ARRAY ))
reserved_ip_ranges: (( grab $BUCC_BOSH_RESERVED_IP_RANGES_YAML_ARRAY ))
concourse_external_worker_ip: (( grab $BUCC_BOSH_STATIC_IP_CONCOURSE_WORKER ))
EOF

spruce merge "${TMPDIR}"/deploy-inputs.yml | grep -v password
spruce merge "${TMPDIR}"/deploy-inputs.yml > "${STATE_VARS_FILE}"

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



