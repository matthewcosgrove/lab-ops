#!/bin/bash

set -euo pipefail

crednames=( \
  vcenter_username \
  vcenter_password
)
credpath_prefix="/concourse/main/"
for credname in "${crednames[@]}"
do
  credpath="${credpath_prefix}${credname}"
  if ! credhub get -n "${credpath}" > /dev/null 2>&1;then
    echo "Please enter cred for: ${credpath}"
    if [[ "${credname}" == *password ]];then
      credhub set -n "${credpath}" -t password
    else
      credhub set -n "${credpath}" -t value
    fi
  else
    echo "${credpath} already created, skipping.."
  fi
done

credhub set -n "${credpath_prefix}"govc_url -t value -v "${GOVC_URL}"
credhub set -n "${credpath_prefix}"govc_datacenter -t value -v "${GOVC_DATACENTER}"
credhub set -n "${credpath_prefix}"govc_cluster -t value -v "${GOVC_CLUSTER}"
credhub set -n "${credpath_prefix}"govc_network -t value -v "${GOVC_NETWORK}"
credhub set -n "${credpath_prefix}"govc_vm_folder_path -t value -v "${GOVC_VM_FOLDER_PATH}"

credhub set -n "${credpath_prefix}"vcenter_primary_datastore -t value -v "${VCENTER_PRIMARY_DATASTORE}"
credhub set -n "${credpath_prefix}"vcenter_resource_pool_name -t value -v "${VCENTER_RESOURCE_POOL_NAME}"
credhub set -n "${credpath_prefix}"vcenter_folder_name -t value -v "${VCENTER_FOLDER_NAME}"
