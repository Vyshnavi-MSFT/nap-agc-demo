#!/usr/bin/env bash
# PASS/FAIL test suite for the demo end state.

set -uo pipefail

pass=0 ; fail=0
check() {
  local name="$1" ; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $name"
    pass=$((pass+1))
  else
    echo "FAIL  $name"
    fail=$((fail+1))
  fi
}

echo "=== NAP / NodePool ==="
check "NodePool exists"       kubectl get nodepool default
check "NodePool Ready=True"   bash -c "[[ \$(kubectl get nodepool default -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}') == True ]]"
check "D-family node present" bash -c "kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.labels.karpenter\\.azure\\.com/sku-name}{\"\n\"}{end}' | grep -q '^Standard_D'"
check "E-family node present" bash -c "kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.labels.karpenter\\.azure\\.com/sku-name}{\"\n\"}{end}' | grep -q '^Standard_E'"

echo
echo "=== Workloads ==="
check "shop-v1 Available"       kubectl wait --for=condition=Available --timeout=10s deployment/shop-v1
check "recommender Available"   kubectl wait --for=condition=Available --timeout=10s deployment/recommender

echo
echo "=== AGC ==="
check "Gateway Programmed"      bash -c "[[ \$(kubectl get gateway gateway-01 -o jsonpath='{.status.conditions[?(@.type==\"Programmed\")].status}') == True ]]"
ADDR=$(kubectl get gateway gateway-01 -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
check "Gateway address present" bash -c "[[ -n '$ADDR' ]]"
check "HTTP 200 from AGC"       bash -c "[[ \$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://$ADDR/) == 200 ]]"

echo
echo "=== Summary ==="
echo "PASS: $pass    FAIL: $fail"
exit $(( fail == 0 ? 0 : 1 ))
