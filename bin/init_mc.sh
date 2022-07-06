#!/bin/bash

set -eu

set_minio_vars() {
    echo "Checking credhub is ready"
    credhub find | grep minio
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
    mc_cli_minio_url=$(credhub get -n "${credhub_key_minio_url}" -q)
    mc_cli_minio_access_key=$(credhub get -n /concourse/main/minio_access_key -q)
    mc_cli_minio_secret_key=$(credhub get -n /concourse/main/minio_secret_key -q)

    echo "Setting up mc cli for Minio:"
    echo "  url: ${mc_cli_minio_url}"
    echo "  access_key: ${mc_cli_minio_access_key}"
}

set_minio_vars

mc alias set bucc "${mc_cli_minio_url}" "${mc_cli_minio_access_key}" "${mc_cli_minio_secret_key}"

# clean up superfluous defaults
set +e
mc alias rm gcs >> /dev/null 2>&1
mc alias rm s3 >> /dev/null 2>&1
set -e