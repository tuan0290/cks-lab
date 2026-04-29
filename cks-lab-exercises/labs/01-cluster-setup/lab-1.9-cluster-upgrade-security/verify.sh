#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Cluster Upgrade Security ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-1-9 &>/dev/null && check "Namespace lab-1-9 exists" "pass" "" || check "Namespace lab-1-9 exists" "fail" "Run ./setup.sh"
kubectl get configmap cluster-version-info -n lab-1-9 &>/dev/null && check "ConfigMap cluster-version-info exists" "pass" "" || check "ConfigMap cluster-version-info exists" "fail" "Create cluster-version-info ConfigMap"
kubectl get configmap deprecated-apis -n lab-1-9 &>/dev/null && check "ConfigMap deprecated-apis exists" "pass" "" || check "ConfigMap deprecated-apis exists" "fail" "Create deprecated-apis ConfigMap"
kubectl get configmap upgrade-security-checklist -n lab-1-9 &>/dev/null && check "ConfigMap upgrade-security-checklist exists" "pass" "" || check "ConfigMap upgrade-security-checklist exists" "fail" "Create upgrade-security-checklist ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
