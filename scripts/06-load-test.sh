#!/usr/bin/env bash
# Generate sustained traffic against AGC and report per-pod hit distribution.
# Requires manifests/nginx-podname-config.yaml — nginx echoes its hostname
# (= pod name) so we can count hits per pod from outside the cluster.

set -euo pipefail

REQUESTS="${REQUESTS:-200}"     # total requests to send
PARALLEL="${PARALLEL:-10}"      # concurrent curls

ADDR=$(kubectl get gateway gateway-01 -o jsonpath='{.status.addresses[0].value}')
[[ -n "$ADDR" ]] || { echo "Gateway address not ready"; exit 1; }

echo "==> Target: http://$ADDR/"
echo "==> Sending $REQUESTS requests, $PARALLEL in parallel..."
echo

# Use xargs to parallelize curls and capture each pod name.
seq 1 "$REQUESTS" \
  | xargs -P "$PARALLEL" -I{} curl -s --max-time 5 "http://$ADDR/" \
  | sort | uniq -c | sort -rn \
  | awk 'BEGIN{
           printf "  %-6s  %s\n", "HITS", "POD";
           printf "  %-6s  %s\n", "----", "---";
         }
         { printf "  %-6d  %s\n", $1, $2 }'

echo
echo "==> Tip: for live per-pod CPU during load, run in another pane:"
echo "     kubectl top pods -l app=shop-v1 --containers --watch"
