#!/bin/bash

set -euo pipefail

resource_pool_parent=/"${GOVC_DATACENTER}"/host/"${GOVC_CLUSTER}"/Resources
echo "Self identifiers.."
govc pool.info -json "${resource_pool_parent}" | jq .ResourcePools[0].Self
echo "Parent identifiers.."
govc pool.info -json "${resource_pool_parent}" | jq .ResourcePools[0].Parent

echo "Adding new resource pool under $resource_pool_parent"
govc pool.create "${resource_pool_parent}"/"${GOVC_RESOURCE_POOL}"
