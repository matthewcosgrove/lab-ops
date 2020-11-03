#!/bin/bash

: "${GOVC_URL:? GOVC_URL must be set (use init-govc for convenience) }"
: "${GOVC_USERNAME:? GOVC_USERNAME must be set (use init-govc for convenience) }"
: "${GOVC_PASSWORD:? GOVC_PASSWORD must be set (use init-govc for convenience) }"

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR"/bucc_wrapper_helpers.sh

function destroy() {
  CLEANUP_VM_WITH_IP=$1
  echo "Destroy VM: $CLEANUP_VM_WITH_IP"
  govc vm.info -vm.ip "${CLEANUP_VM_WITH_IP}"
  rc=$?; if [[ $rc != 0 ]]; then return $rc; fi
  # https://github.com/starkandwayne/bucc/blob/86c85b138d4ef4d243e4e79d8640f7e2a8f98514/ci/tasks/cleanup-vshpere-ci-vm/task
  templates=$(govc vm.info -vm.ip "${CLEANUP_VM_WITH_IP}" -json | grep -o 'sc-[-[:alnum:]]*' | sort -u | head -1)
  govc vm.destroy -vm.ip "${CLEANUP_VM_WITH_IP}" | true

  echo "VM with IP ${CLEANUP_VM_WITH_IP} destroyed, removing associated stemcells"
  for del in $templates; do
    remove=$(echo "${del}" | xargs ) # remove leading spaces
    echo "deleting ${del}"
    govc vm.destroy "${VCENTER_STEMCELL_FOLDER_PATH}"/"${remove}"
  done
}

function destroy_by_vm_name() {
  CLEANUP_VM_WITH_NAME=$1
  echo "Destroy VM: $CLEANUP_VM_WITH_NAME"
  govc vm.info "${CLEANUP_VM_WITH_NAME}"
  rc=$?; if [[ "$rc" != 0 ]]; then return "$rc"; fi
  # https://github.com/starkandwayne/bucc/blob/86c85b138d4ef4d243e4e79d8640f7e2a8f98514/ci/tasks/cleanup-vshpere-ci-vm/task
  templates=$(govc vm.info "${CLEANUP_VM_WITH_NAME}" -json | grep -o 'sc-[-[:alnum:]]*' | sort -u | head -1)
  govc vm.destroy "${CLEANUP_VM_WITH_NAME}" | true

  echo "Removing associated stemcells"
  for del in $templates; do
    remove=$(echo "${del}" | xargs ) # remove leading spaces
    echo "deleting ${del}"
    govc vm.destroy "${VCENTER_STEMCELL_FOLDER_PATH}"/"${remove}"
  done
}

GOVC_DATACENTER=$(spruce json "${STATE_VARS_FILE}" | jq -r '.vcenter_dc')
echo "Brute force teardown for target ${GOVC_DATACENTER} in ${GOVC_URL} with user ${GOVC_USERNAME}"

concourse_external_worker_ip=$(spruce json "${STATE_VARS_FILE}" | jq -r '.concourse_external_worker_ip')
vcenter_templates=$(spruce json "${STATE_VARS_FILE}" | jq -r '.vcenter_templates')
export VCENTER_STEMCELL_FOLDER_PATH="/$GOVC_DATACENTER/vm/$vcenter_templates"
bucc_vm_name=$(jq -r '.current_vm_cid' < "${STATE_VARS_DIR}"/bosh-state.json)

set +e
echo "Destroy Concourse Worker VM"
destroy "${concourse_external_worker_ip}"
echo "Destroy BUCC VM, try by name (have seen issues with vcenter hiding the IP time to time)"
destroy_by_vm_name "${bucc_vm_name}"
set -e

# Any other leftovers..
echo "Delete all stemcells in Path ${VCENTER_STEMCELL_FOLDER_PATH}"
govc ls "${VCENTER_STEMCELL_FOLDER_PATH}" > tmp-stemcells.txt
set -e

while IFS="" read -r p || [ -n "$p" ]
do
    echo "deleting ${p}"
    set +e
    govc vm.destroy "${p}"
    set -e

done < tmp-stemcells.txt
rm tmp-stemcells.txt

echo "All stemcells removed for PATH ${VCENTER_STEMCELL_FOLDER_PATH}"

