#!/bin/bash

: "${GOVC_PASSWORD:?bin/deploy.sh - GOVC_PASSWORD must be set}"
: "${GOVC_USERNAME:?bin/deploy.sh - GOVC_USERNAME must be set}"
: "${BBL_STATE_DIR:? BBL_STATE_DIR must be set for BUCC to use. See README for details }"

set -euo pipefail

TMPDIR=""
TMPDIR=$(mktemp -d -t deploy.sh.XXXXXX)
trap 'rm -rf ${TMPDIR}' INT TERM QUIT EXIT

REPO_ROOT_DIR="$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )")"
STATE_ROOT_DIR="$BBL_STATE_DIR/.."
STATE_VARS_DIR="$BBL_STATE_DIR/vars"

# Idempotent approach which is meant to affect first run through to prevent BUCC generating the vars file https://github.com/starkandwayne/bucc/blob/2af7a2b47a151007b4db089f2349aa58bce8d1fc/bin/bucc#L69
mkdir -p "$STATE_VARS_DIR"
touch "$STATE_VARS_DIR/director-vars-file.yml"
cat <<EOF > "$STATE_VARS_DIR/flags"
dns
resource-pool
EOF

# prepare ops files by copying over the ones based on if config has been provided
STATE_OPERATORS_DIR="$BBL_STATE_DIR/operators"
SOURCE_OPERATORS_DIR="$REPO_ROOT_DIR/ops-files"
echo "Checking if vcenter_ca_cert needs to be configured"
set +e # tolerate failure if not present
vcenter_ca_cert=$(bosh int "$STATE_ROOT_DIR/infra-settings.yml" --path /vcenter_ca_cert)
set -e
if [ ! -z "$vcenter_ca_cert" ]; then
  ops_file_name="z-custom-ca.yml"
  cat "$SOURCE_OPERATORS_DIR/$ops_file_name"
  mkdir -p "$STATE_OPERATORS_DIR"
  cp "$SOURCE_OPERATORS_DIR/$ops_file_name" "$STATE_OPERATORS_DIR"
  echo "Adding ops file $ops_file_name"
else
  echo "No vcenter_ca_cert config found so ignoring. If required add it to the file $STATE_ROOT_DIR/infra-settings.yml"
fi

cat <<EOF > ${TMPDIR}/deploy-inputs.yml
vcenter_password: '${GOVC_PASSWORD}'
vcenter_user: '${GOVC_USERNAME}'
EOF

spruce merge "$STATE_ROOT_DIR/infra-settings.yml" \
        "${TMPDIR}/deploy-inputs.yml" \
        > "$STATE_VARS_DIR/director-vars-file.yml"

"${REPO_ROOT_DIR}"/bin/bucc_wrapper.sh up --cpi vsphere --debug
echo "Deploy completed successfully"

echo "Testing state files for BUCC."
source <("$REPO_ROOT_DIR"/bin/env)

echo "Start the BUCC tests..."
"$REPO_ROOT_DIR"/src/bucc/bin/bucc test

echo "Start custom tests"
source "$REPO_ROOT_DIR"/bin/test_default_concourse_worker_exists.sh

