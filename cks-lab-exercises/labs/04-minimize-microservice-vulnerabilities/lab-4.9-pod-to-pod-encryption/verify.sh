#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Pod-to-Pod Encryption ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-4-9 &>/dev/null && check "Namespace lab-4-9 exists" "pass" "" || check "Namespace lab-4-9 exists" "fail" "Run ./setup.sh"
kubectl get secret service-tls -n lab-4-9 &>/dev/null && check "Secret service-tls exists" "pass" "" || check "Secret service-tls exists" "fail" "Create service-tls TLS secret"
kubectl get pod tls-server -n lab-4-9 &>/dev/null && check "Pod tls-server exists" "pass" "" || check "Pod tls-server exists" "fail" "Create tls-server pod"
kubectl get configmap mtls-config -n lab-4-9 &>/dev/null && check "ConfigMap mtls-config exists" "pass" "" || check "ConfigMap mtls-config exists" "fail" "Create mtls-config ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
