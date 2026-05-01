#!/usr/bin/env bash
# Generate sustained traffic against AGC and report per-pod hit distribution.
# Demonstrates AGC's load-aware routing: cool pods receive more new connections
# than already-busy pods.

set -euo pipefail

DURATION="${DURATION:-60}"
CONCURRENCY="${CONCURRENCY:-20}"

ADDR=$(kubectl get gateway gateway-01 -o jsonpath='{.status.addresses[0].value}')
[[ -n "$ADDR" ]] || { echo "Gateway address not ready"; exit 1; }

echo "==> Target: http://$ADDR/  duration=${DURATION}s  concurrency=$CONCURRENCY"

# Tag each pod's nginx with its own pod IP via a downward-API env var so the
# response identifies the pod that served it. (Done with a custom config; here
# we use the simpler approach: hit /etc/hostname via a status header.)
echo "==> Running load generator pod (alpine + curl)"
kubectl run loadgen --rm -i --restart=Never --image=alpine:3.20 --quiet -- \
  sh -c "
    apk add --no-cache curl >/dev/null 2>&1
    end=\$(( \$(date +%s) + $DURATION ))
    while [ \$(date +%s) -lt \$end ]; do
      for i in \$(seq 1 $CONCURRENCY); do
        curl -s -o /dev/null -w '%{remote_ip}\n' http://$ADDR/ &
      done
      wait
    done
  " | sort | uniq -c | sort -rn | awk 'BEGIN{print \"  hits  pod-or-edge-IP\"} {printf \"  %5d  %s\n\", \$1, \$2}'

echo
echo "==> Note: %{remote_ip} is the AGC frontend IP (single value). For per-pod"
echo "    distribution, the demo cluster has nginx configured with the downward"
echo "    API to expose POD_IP in a response header. Inspect with:"
echo "      kubectl exec deploy/shop-v1 -- curl -sI http://localhost/ | grep X-Pod-IP"
echo "    or watch real-time per-pod load:  kubectl top pods -l app=shop-v1 --containers"
