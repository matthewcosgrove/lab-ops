#!/bin/bash

set -euo pipefail

pip3 install aiohttp
ansible-galaxy collection install vmware.vmware_rest
