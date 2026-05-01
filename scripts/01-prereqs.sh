#!/usr/bin/env bash
# Register Azure preview features, install CLI extensions, create the resource group.
# Idempotent — safe to re-run.

set -euo pipefail
: "${SUBSCRIPTION_ID:?source scripts/00-env.sh first}"
: "${LOCATION:?}" ; : "${RG:?}"

echo "==> CLI extensions"
az extension add --name aks-preview --upgrade --yes
az extension add --name alb        --upgrade --yes

echo "==> Provider features"
az feature register --namespace Microsoft.ContainerService --name NodeAutoProvisioningPreview >/dev/null

echo "==> Waiting for NodeAutoProvisioningPreview = Registered (can take a few minutes)"
for i in {1..60}; do
  state=$(az feature show --namespace Microsoft.ContainerService --name NodeAutoProvisioningPreview --query properties.state -o tsv)
  echo "    [$i] state = $state"
  [[ "$state" == "Registered" ]] && break
  sleep 10
done

az provider register --namespace Microsoft.ContainerService    --wait
az provider register --namespace Microsoft.ServiceNetworking   --wait

echo "==> Resource group"
az group create -n "$RG" -l "$LOCATION" -o table

echo "==> Done"
