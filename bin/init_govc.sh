#!/bin/bash

: "${BBL_STATE_DIR:? BBL_STATE_DIR must be set for BUCC to use. See README for details }"
export INFRA_SETTINGS_FILE=$BBL_STATE_DIR/../infra-settings.yml
export FINAL_INFRA_SETTINGS_FILE=$BBL_STATE_DIR/vars/director-vars-file.yml

govc_url=$(spruce json "$INFRA_SETTINGS_FILE" | jq -re '.vcenter_ip')
if [[ $? -ne 0 ]]; then
  grep vcenter_ip < "$INFRA_SETTINGS_FILE"
  echo "[FATAL] vcenter_ip not found in $INFRA_SETTINGS_FILE"
  exit 1
fi
govc_dc=$(spruce json "$INFRA_SETTINGS_FILE" | jq -re '.vcenter_dc')
if [[ $? -ne 0 ]]; then
  grep vcenter_dc < "$INFRA_SETTINGS_FILE"
  echo "[FATAL] vcenter_dc not found in $INFRA_SETTINGS_FILE"
  exit 1
fi
export GOVC_URL=$govc_url
export GOVC_DATACENTER=$govc_dc
export GOVC_INSECURE=true # don't do this at home kids
env | grep GOVC_URL
if [[ -f $FINAL_INFRA_SETTINGS_FILE ]];then
  echo "Parsing creds from $FINAL_INFRA_SETTINGS_FILE"
  govc_username=$(spruce json "$FINAL_INFRA_SETTINGS_FILE" | jq -re '.vcenter_user')
  if [[ $? -ne 0 ]]; then
    grep vcenter_user < "$FINAL_INFRA_SETTINGS_FILE"
    echo "[FATAL] vcenter_user not found in $FINAL_INFRA_SETTINGS_FILE"
    exit 1
  fi
  govc_password=$(spruce json "$FINAL_INFRA_SETTINGS_FILE" | jq -re '.vcenter_password')
  if [[ $? -ne 0 ]]; then
    grep vcenter_password < "$FINAL_INFRA_SETTINGS_FILE"
    echo "[FATAL] vcenter_password not found in $FINAL_INFRA_SETTINGS_FILE"
    exit 1
  fi
  export GOVC_USERNAME=$govc_username
  export GOVC_PASSWORD=$govc_password
else
  echo "$FINAL_INFRA_SETTINGS_FILE does not yet exist locally so env vars GOVC_USERNAME and GOVC_PASSWORD will need to be set manually"
fi
echo "[TEST] govc ls command"
govc ls
