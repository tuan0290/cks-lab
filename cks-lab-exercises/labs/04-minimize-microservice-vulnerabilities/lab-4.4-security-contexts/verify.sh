#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Security Contexts ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-4-4 &>/dev/null && check "Namespace lab-4-4 exists" "pass" "" || check "Namespace lab-4-4 exists" "fail" "Run ./setup.sh"
kubectl get pod secure-app -n lab-4-4 &>/dev/null && check "Pod secure-app exists" "pass" "" || check "Pod secure-app exists" "fail" "Create secure-app pod"

RUN_AS_NON_ROOT=$(kubectl get pod secure-app -n lab-4-4 -o jsonpath='{.spec.securityContext.runAsNonRoot}' 2>/dev/null)
[ "$RUN_AS_NON_ROOT" = "true" ] && check "secure-app has runAsNonRoot: true" "pass" "" || check "secure-app has runAsNonRoot: true" "fail" "Set securityContext.runAsNonRoot: true"

RUN_AS_USER=$(kubectl get pod secure-app -n lab-4-4 -o jsonpath='{.spec.securityContext.runAsUser}' 2>/dev/null)
[ "$RUN_AS_USER" = "1000" ] && check "secure-app runs as user 1000" "pass" "" || check "secure-app runs as user 1000" "fail" "Set securityContext.runAsUser: 1000"

NO_PRIV_ESC=$(kubectl get pod secure-app -n lab-4-4 -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)
[ "$NO_PRIV_ESC" = "false" ] && check "secure-app has allowPrivilegeEscalation: false" "pass" "" || check "secure-app has allowPrivilegeEscalation: false" "fail" "Set containers[0].securityContext.allowPrivilegeEscalation: false"

kubectl get pod multi-container-app -n lab-4-4 &>/dev/null && check "Pod multi-container-app exists" "pass" "" || check "Pod multi-container-app exists" "fail" "Create multi-container-app pod"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
