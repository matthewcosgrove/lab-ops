#!/bin/bash

set -euo pipefail

credpath="/concourse/main/git_ssh"
if ! credhub get -n "${credpath}" > /dev/null 2>&1;then
  echo "Re-using pre-generated keys for Concourse access to Git (bosh gateway user)"
  # https://github.com/starkandwayne/bucc/blob/master/ops/1-gateway-user.yml
  public_key=$(bucc int --path /instance_groups/name=bosh/jobs/name=user_add/properties/users/name=gateway/public_key)
  private_key=$(credhub get -n /concourse/main/bosh_gw_private_key -q)
  
  credhub set -t ssh -n "${credpath}" -p "$private_key" -u "$public_key"
else
  echo "${credpath} already created, skipping.." 
fi
  
echo "Place the following key in the git account for your Concourse technical user"
credhub get -n "${credpath}" -k public_key
