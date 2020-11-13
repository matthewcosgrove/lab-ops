#!/bin/bash

set -euo pipefail

credpath_prefix="/concourse/main/"

function credhub_set(){
  local credname="${1}"
  local credpath="${credpath_prefix}${credname}"
  if ! credhub get -n "${credpath}" > /dev/null 2>&1;then
    echo "Setting credential for ${credpath}"
    credhub set -n "${credpath}" -t value -v "${2}"
  else
    echo "${credpath} already created, skipping... NOTE: if required to change run command manually \"credhub set -n "${credpath}" -t value\" "
  fi
}

credhub_set govc_url "${GOVC_URL}"
credhub_set vcenter_username "${GOVC_USERNAME}"
credhub_set vcenter_password "${GOVC_PASSWORD}"
credhub_set govc_datacenter "${GOVC_DATACENTER}"
credhub_set govc_cluster "${GOVC_CLUSTER}"
credhub_set govc_network "${GOVC_NETWORK}"
credhub_set govc_folder "${GOVC_FOLDER}"
credhub_set govc_vm_folder_path "${GOVC_FOLDER}" # keeping for backwards compatibility
credhub_set govc_folder_path_prefix "/${GOVC_DATACENTER}/vm/" # path prefix expected by govc useful for combining with VCENTER_FOLDER_NAME_RELATIVE_PATH because GOVC_FOLDER=govc_folder_path_prefix/VCENTER_FOLDER_NAME_RELATIVE_PATH

credhub_set vcenter_primary_datastore "${GOVC_DATASTORE}"
credhub_set vcenter_resource_pool_name "${VCENTER_RESOURCE_POOL_NAME}"
credhub_set vcenter_folder_name "${VCENTER_FOLDER_NAME_RELATIVE_PATH}"
