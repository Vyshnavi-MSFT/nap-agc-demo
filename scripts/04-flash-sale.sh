#!/usr/bin/env bash
# Trigger the flash-sale scenario: deploy the memory-heavy recommender AND
# scale shop-v1 from 2 to 6 replicas. Watch a new E-family node appear.

set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Deploying recommender (3 pods x 4 CPU / 10 Gi each)"
kubectl apply -f manifests/deployment-large.yaml

echo "==> Scaling shop-v1 to simulate the email-blast spike"
kubectl scale deployment shop-v1 --replicas=6

echo "==> Waiting for both deployments to be Available"
kubectl wait --for=condition=Available deployment/recommender --timeout=420s
kubectl wait --for=condition=Available deployment/shop-v1     --timeout=300s

echo "==> Final placement"
kubectl get nodes --show-labels | grep karpenter.azure.com/sku-name || true
echo
kubectl get pods -o wide
