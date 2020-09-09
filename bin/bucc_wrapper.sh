#!/bin/bash

set -euo pipefail

REPO_ROOT_DIR="$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )")"
: "${BBL_STATE_DIR:? BBL_STATE_DIR must be set for BUCC to use. See README for details }"
bucc_submodule_location=$REPO_ROOT_DIR/src/bucc
bucc_cmd="$bucc_submodule_location/bin/bucc"

function err_fatal() {
  echo "[FATAL] $(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
  exit 1
}

function credhub_login() {
  echo "Using credhub CLI managed by BUCC.."
  if ! $bucc_cmd credhub > /dev/null; then
    err_fatal "Cannot login into credhub via BUCC"
  fi
}

info() {
    credhub_login
    local credhub_key_minio_url="/concourse/main/minio_url"
    set +e
    credhub get -n "${credhub_key_minio_url}" > /dev/null
    if [ $? -ne 0 ]; then
      set -e
      echo "Could not find ${credhub_key_minio_url} in CredHub"
      echo "Minio does not seem to be deployed yet, skipping info for Minio"
      return
    fi
    set -e
    local minio_url=$(credhub get -n "${credhub_key_minio_url}" -q)
    local minio_access_key=$(credhub get -n /concourse/main/minio_access_key -q)
    local minio_secret_key=$(credhub get -n /concourse/main/minio_secret_key -q)

    echo "Minio:"
    echo "  url: ${minio_url}"
    echo "  access_key: ${minio_access_key}"
    echo "  secret_key: ${minio_secret_key}"
}

case "$1" in
    info)
        #_ensure_minio_cli_installed
        shift
        $bucc_cmd info "$@"
	info "$@"
        ;;

    *)
        $bucc_cmd "$@"
        ;;
esac
