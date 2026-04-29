#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: ServiceAccount Token Management ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-2-5 &>/dev/null && check "Namespace lab-2-5 exists" "pass" "" || check "Namespace lab-2-5 exists" "fail" "Run ./setup.sh"

SA_AUTOMOUNT=$(kubectl get serviceaccount no-token-sa -n lab-2-5 -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
[ "$SA_AUTOMOUNT" = "false" ] && check "ServiceAccount no-token-sa has automountServiceAccountToken: false" "pass" "" || check "ServiceAccount no-token-sa has automountServiceAccountToken: false" "fail" "Set automountServiceAccountToken: false on the ServiceAccount"

POD_AUTOMOUNT=$(kubectl get pod no-token-pod -n lab-2-5 -o jsonpath='{.spec.automountServiceAccountToken}' 2>/dev/null)
[ "$POD_AUTOMOUNT" = "false" ] && check "Pod no-token-pod has automountServiceAccountToken: false" "pass" "" || check "Pod no-token-pod has automountServiceAccountToken: false" "fail" "Set automountServiceAccountToken: false in pod spec"

kubectl get serviceaccount api-reader-sa -n lab-2-5 &>/dev/null && check "ServiceAccount api-reader-sa exists" "pass" "" || check "ServiceAccount api-reader-sa exists" "fail" "Create api-reader-sa ServiceAccount"
kubectl get role pod-reader -n lab-2-5 &>/dev/null && check "Role pod-reader exists" "pass" "" || check "Role pod-reader exists" "fail" "Create pod-reader Role"
kubectl get rolebinding api-reader-binding -n lab-2-5 &>/dev/null && check "RoleBinding api-reader-binding exists" "pass" "" || check "RoleBinding api-reader-binding exists" "fail" "Create api-reader-binding RoleBinding"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
