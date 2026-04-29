#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Minimizing Host OS Footprint ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-3-5 &>/dev/null && check "Namespace lab-3-5 exists" "pass" "" || check "Namespace lab-3-5 exists" "fail" "Run ./setup.sh"
kubectl get pod secure-pod -n lab-3-5 &>/dev/null && check "Pod secure-pod exists" "pass" "" || check "Pod secure-pod exists" "fail" "Create secure-pod"

HOST_PID=$(kubectl get pod secure-pod -n lab-3-5 -o jsonpath='{.spec.hostPID}' 2>/dev/null)
[ "$HOST_PID" != "true" ] && check "Pod secure-pod does not use hostPID" "pass" "" || check "Pod secure-pod does not use hostPID" "fail" "Set hostPID: false in pod spec"

HOST_NET=$(kubectl get pod secure-pod -n lab-3-5 -o jsonpath='{.spec.hostNetwork}' 2>/dev/null)
[ "$HOST_NET" != "true" ] && check "Pod secure-pod does not use hostNetwork" "pass" "" || check "Pod secure-pod does not use hostNetwork" "fail" "Set hostNetwork: false in pod spec"

kubectl get configmap host-footprint-checklist -n lab-3-5 &>/dev/null && check "ConfigMap host-footprint-checklist exists" "pass" "" || check "ConfigMap host-footprint-checklist exists" "fail" "Create host-footprint-checklist ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
