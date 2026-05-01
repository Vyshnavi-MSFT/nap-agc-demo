#!/usr/bin/env bash
# Create an AKS cluster with Cilium + NAP + AGC (ALB Controller add-on).

set -euo pipefail
: "${SUBSCRIPTION_ID:?source scripts/00-env.sh first}"
: "${LOCATION:?}" ; : "${RG:?}" ; : "${CLUSTER:?}"

echo "==> Creating AKS cluster $CLUSTER in $RG ($LOCATION)"
az aks create \
  -n "$CLUSTER" -g "$RG" -l "$LOCATION" \
  --network-plugin azure --network-plugin-mode overlay \
  --network-dataplane cilium \
  --node-provisioning-mode Auto \
  --node-count 1 \
  --generate-ssh-keys \
  -o table

echo "==> Fetching kubeconfig"
az aks get-credentials -n "$CLUSTER" -g "$RG" --overwrite-existing

echo "==> Enabling ALB Controller add-on (programs AGC)"
az aks addon enable -n "$CLUSTER" -g "$RG" --addon alb-controller -o table

echo "==> Waiting for ALB Controller pods to be Ready"
kubectl wait --for=condition=Ready pods --all -n azure-alb-system --timeout=300s

echo "==> Sanity checks"
kubectl get nodes
kubectl get pods -n azure-alb-system
az aks show -n "$CLUSTER" -g "$RG" --query "nodeProvisioningProfile.mode" -o tsv

echo "==> Done"
