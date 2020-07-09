#!/bin/bash

set -euo pipefail

crednames=( \
  vcenter_username \
  vcenter_password
)
for credname in "${crednames[@]}"
do
  credpath="/concourse/main/${credname}"
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
