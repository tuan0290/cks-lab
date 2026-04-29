#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Node Metadata Protection ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-1-7 &>/dev/null && check "Namespace lab-1-7 exists" "pass" "" || check "Namespace lab-1-7 exists" "fail" "Run ./setup.sh"
kubectl get networkpolicy block-metadata -n lab-1-7 &>/dev/null && check "NetworkPolicy block-metadata exists" "pass" "" || check "NetworkPolicy block-metadata exists" "fail" "Create NetworkPolicy block-metadata"

NP_EGRESS=$(kubectl get networkpolicy block-metadata -n lab-1-7 -o jsonpath='{.spec.policyTypes[0]}' 2>/dev/null)
[ "$NP_EGRESS" = "Egress" ] && check "NetworkPolicy has Egress policyType" "pass" "" || check "NetworkPolicy has Egress policyType" "fail" "Add policyTypes: [Egress]"

NP_EXCEPT=$(kubectl get networkpolicy block-metadata -n lab-1-7 -o jsonpath='{.spec.egress[0].to[0].ipBlock.except[0]}' 2>/dev/null)
[ "$NP_EXCEPT" = "169.254.169.254/32" ] && check "NetworkPolicy blocks 169.254.169.254/32" "pass" "" || check "NetworkPolicy blocks 169.254.169.254/32" "fail" "Add ipBlock.except: [169.254.169.254/32]"

kubectl get pod test-pod -n lab-1-7 &>/dev/null && check "Pod test-pod exists" "pass" "" || check "Pod test-pod exists" "fail" "Create test-pod in namespace lab-1-7"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
