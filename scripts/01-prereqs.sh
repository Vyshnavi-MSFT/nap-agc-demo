#!/usr/bin/env bash
# Register Azure preview features, install CLI extensions, create the resource group.
# Idempotent — safe to re-run.

set -euo pipefail
: "${SUBSCRIPTION_ID:?source scripts/00-env.sh first}"
: "${LOCATION:?}" ; : "${RG:?}"

echo "==> Azure CLI version check (NAP requires >= 2.76.0)"
CLI_VER=$(az version --query '"azure-cli"' -o tsv)
echo "    az CLI = $CLI_VER"
if [[ "$(printf '%s\n' "2.76.0" "$CLI_VER" | sort -V | head -n1)" != "2.76.0" ]]; then
  echo "    ERROR: az CLI is older than 2.76.0. Run:  az upgrade --yes"
  echo "    (Or on Windows: winget upgrade --id Microsoft.AzureCLI)"
  exit 1
fi

echo "==> CLI extensions (refresh to match base CLI)"
az extension add --name aks-preview --upgrade --allow-preview true
az extension add --name alb         --upgrade --allow-preview true

echo "==> Provider registration"
echo "    (NAP is GA — no preview feature flag needed.)"
az provider register --namespace Microsoft.ContainerService    --wait
az provider register --namespace Microsoft.ServiceNetworking   --wait

echo "==> Resource group"
az group create -n "$RG" -l "$LOCATION" -o table

echo "==> Done"
