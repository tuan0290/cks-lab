#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Secret Management ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-4-5 &>/dev/null && check "Namespace lab-4-5 exists" "pass" "" || check "Namespace lab-4-5 exists" "fail" "Run ./setup.sh"
kubectl get secret db-credentials -n lab-4-5 &>/dev/null && check "Secret db-credentials exists" "pass" "" || check "Secret db-credentials exists" "fail" "Create db-credentials secret"
kubectl get serviceaccount app-sa -n lab-4-5 &>/dev/null && check "ServiceAccount app-sa exists" "pass" "" || check "ServiceAccount app-sa exists" "fail" "Create app-sa ServiceAccount"
kubectl get role secret-reader -n lab-4-5 &>/dev/null && check "Role secret-reader exists" "pass" "" || check "Role secret-reader exists" "fail" "Create secret-reader Role"
kubectl get rolebinding app-secret-binding -n lab-4-5 &>/dev/null && check "RoleBinding app-secret-binding exists" "pass" "" || check "RoleBinding app-secret-binding exists" "fail" "Create app-secret-binding RoleBinding"
kubectl get pod app-pod -n lab-4-5 &>/dev/null && check "Pod app-pod exists" "pass" "" || check "Pod app-pod exists" "fail" "Create app-pod"

VOL=$(kubectl get pod app-pod -n lab-4-5 -o jsonpath='{.spec.volumes[0].secret.secretName}' 2>/dev/null)
[ "$VOL" = "db-credentials" ] && check "Pod mounts db-credentials as volume" "pass" "" || check "Pod mounts db-credentials as volume" "fail" "Mount db-credentials secret as a volume"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
