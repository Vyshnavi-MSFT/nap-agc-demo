#!/usr/bin/env bash
# Apply NodePool, Service, Gateway, and the baseline shop workload.

set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> NAP NodePool"
kubectl apply -f manifests/nodepool.yaml
kubectl get nodepool

echo "==> AGC ingress (Service + Gateway + HTTPRoute)"
kubectl apply -f manifests/nginx-service.yaml
kubectl apply -f manifests/gateway.yaml

echo "==> Baseline shop workload (2 pods, 2 CPU each)"
kubectl apply -f manifests/deployment-small.yaml

echo "==> Waiting for pods to become Running (NAP will provision a node first)"
kubectl wait --for=condition=Available deployment/shop-v1 --timeout=300s

echo "==> Waiting for Gateway to be Programmed"
for i in {1..30}; do
  programmed=$(kubectl get gateway gateway-01 -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || true)
  echo "    [$i] Programmed = ${programmed:-pending}"
  [[ "$programmed" == "True" ]] && break
  sleep 10
done

AGC_ADDR=$(kubectl get gateway gateway-01 -o jsonpath='{.status.addresses[0].value}')
echo "==> AGC address: $AGC_ADDR"
echo "    Test:  curl http://$AGC_ADDR/"
