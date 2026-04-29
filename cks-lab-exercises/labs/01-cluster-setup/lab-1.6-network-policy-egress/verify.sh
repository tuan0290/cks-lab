#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: NetworkPolicy Egress Control ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-1-6 &>/dev/null && check "Namespace lab-1-6 exists" "pass" "" || check "Namespace lab-1-6 exists" "fail" "Run ./setup.sh"
kubectl get pod backend -n lab-1-6 &>/dev/null && check "Pod backend exists" "pass" "" || check "Pod backend exists" "fail" "Create pod with label app=backend"
kubectl get pod database -n lab-1-6 &>/dev/null && check "Pod database exists" "pass" "" || check "Pod database exists" "fail" "Create pod with label app=database"

NP_TYPE=$(kubectl get networkpolicy backend-egress -n lab-1-6 -o jsonpath='{.spec.policyTypes[0]}' 2>/dev/null)
[ "$NP_TYPE" = "Egress" ] && check "NetworkPolicy backend-egress has Egress policyType" "pass" "" || check "NetworkPolicy backend-egress has Egress policyType" "fail" "Create NetworkPolicy with policyTypes: [Egress]"

NP_SELECTOR=$(kubectl get networkpolicy backend-egress -n lab-1-6 -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null)
[ "$NP_SELECTOR" = "backend" ] && check "NetworkPolicy selects pods with app=backend" "pass" "" || check "NetworkPolicy selects pods with app=backend" "fail" "Set podSelector.matchLabels.app: backend"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
