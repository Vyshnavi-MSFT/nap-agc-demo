#!/usr/bin/env bash
# Source this file before running any of the other scripts:
#   source scripts/00-env.sh

export SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv 2>/dev/null)}"
export LOCATION="${LOCATION:-eastus2}"
export RG="${RG:-nap-agc-demo-rg}"
export CLUSTER="${CLUSTER:-nap-agc-demo}"

echo "SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "LOCATION        = $LOCATION"
echo "RG              = $RG"
echo "CLUSTER         = $CLUSTER"
