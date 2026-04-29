#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: NodeRestriction Admission Controller ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-2-9 &>/dev/null && check "Namespace lab-2-9 exists" "pass" "" || check "Namespace lab-2-9 exists" "fail" "Run ./setup.sh"
kubectl get configmap node-restriction-config -n lab-2-9 &>/dev/null && check "ConfigMap node-restriction-config exists" "pass" "" || check "ConfigMap node-restriction-config exists" "fail" "Create node-restriction-config ConfigMap"
kubectl get configmap node-labels-test -n lab-2-9 &>/dev/null && check "ConfigMap node-labels-test exists" "pass" "" || check "ConfigMap node-labels-test exists" "fail" "Create node-labels-test ConfigMap"

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$NODE" ]; then
    LABEL=$(kubectl get node "$NODE" -o jsonpath='{.metadata.labels.security-zone}' 2>/dev/null)
    [ "$LABEL" = "production" ] && check "Node has label security-zone=production" "pass" "" || check "Node has label security-zone=production" "fail" "Run: kubectl label node $NODE security-zone=production"
fi

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
