#!/bin/bash

set -euo pipefail

REPO_ROOT_DIR="$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )")"
: "${BBL_STATE_DIR:? BBL_STATE_DIR must be set for BUCC to use. See README for details }"

STATE_ROOT_DIR="$BBL_STATE_DIR/.."

INFRA_SETTINGS="$STATE_ROOT_DIR/infra-settings.yml"
spruce merge "$REPO_ROOT_DIR/infra-settings-template.yml" > "$INFRA_SETTINGS"
cat "$INFRA_SETTINGS"

echo "[SUCCESS] The file $INFRA_SETTINGS has been generated and will now become the source of truth for the IaC deployment. Please commit the changes to version control"
pushd "$STATE_ROOT_DIR"
git status
popd
echo "[WARNING] YOU MUST BE IN THE STATE REPO DIR TO COMMIT THESE CHANGES! THE ABOVE OUTPUT IS PURELY FOR INFO AND YOU CANNOT COMMIT FROM HERE DIRECTLY"
echo "FOR YOUR CONVENIENCE HERE ARE THE COMMANDS TO RUN BELOW"
echo "cd $STATE_ROOT_DIR; git add infra-settings.yml; git commit -m \"Generated infra-settings yaml\"; git pull --rebase; git push origin master"
echo "[WARNING] Finally, do not forget this file is only meant to be run once the first time you create this project. To back out of the changes go in to the state repo and git checkout infra-settings.yml"
