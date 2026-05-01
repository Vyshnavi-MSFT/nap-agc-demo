#!/usr/bin/env bash
# Tear down everything by deleting the resource group.

set -euo pipefail
: "${RG:?source scripts/00-env.sh first}"

echo "==> Deleting resource group $RG (this also removes AKS, AGC, identities, IPs, disks)"
az group delete -n "$RG" --yes --no-wait
echo "==> Delete request submitted. Track with:  az group show -n $RG"
