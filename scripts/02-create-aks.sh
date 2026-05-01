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
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-gateway-api \
  --enable-application-load-balancer \
  --node-count 1 \
  --generate-ssh-keys \
  -o table

echo "==> Fetching kubeconfig"
az aks get-credentials -n "$CLUSTER" -g "$RG" --overwrite-existing

echo "==> Waiting for ALB Controller pods to be Ready (in kube-system)"
for i in {1..30}; do
  ready=$(kubectl get pods -n kube-system -l app=alb-controller --no-headers 2>/dev/null | grep -c Running || true)
  echo "    [$i] alb-controller Running pods = $ready"
  [[ "$ready" -ge 1 ]] && break
  sleep 10
done

echo "==> Sanity checks"
kubectl get nodes
kubectl get pods -n kube-system | grep alb-controller
kubectl get gatewayclass azure-alb-external
az aks show -n "$CLUSTER" -g "$RG" --query "nodeProvisioningProfile.mode" -o tsv

echo "==> Done"
