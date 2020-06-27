#!/bin/bash

set -euo pipefail

REPO_ROOT_DIR="$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )")"
: "${BBL_STATE_DIR:? BBL_STATE_DIR must be set for BUCC to use. See README for details }"
bucc_submodule_location=$REPO_ROOT_DIR/src/bucc
bucc_cmd="$bucc_submodule_location/bin/bucc"

$bucc_cmd "$@"

