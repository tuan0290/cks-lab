#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: NetworkPolicy for Microservices ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-4-6 &>/dev/null && check "Namespace lab-4-6 exists" "pass" "" || check "Namespace lab-4-6 exists" "fail" "Run ./setup.sh"
for pod in frontend backend database; do
    kubectl get pod $pod -n lab-4-6 &>/dev/null && check "Pod $pod exists" "pass" "" || check "Pod $pod exists" "fail" "Create $pod pod with label tier=$pod"
done
kubectl get networkpolicy default-deny -n lab-4-6 &>/dev/null && check "NetworkPolicy default-deny exists" "pass" "" || check "NetworkPolicy default-deny exists" "fail" "Create default-deny NetworkPolicy"
kubectl get networkpolicy allow-frontend-to-backend -n lab-4-6 &>/dev/null && check "NetworkPolicy allow-frontend-to-backend exists" "pass" "" || check "NetworkPolicy allow-frontend-to-backend exists" "fail" "Create allow-frontend-to-backend NetworkPolicy"
kubectl get networkpolicy allow-backend-to-database -n lab-4-6 &>/dev/null && check "NetworkPolicy allow-backend-to-database exists" "pass" "" || check "NetworkPolicy allow-backend-to-database exists" "fail" "Create allow-backend-to-database NetworkPolicy"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
