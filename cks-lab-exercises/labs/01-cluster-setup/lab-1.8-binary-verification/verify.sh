#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Kubernetes Binary Verification ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-1-8 &>/dev/null && check "Namespace lab-1-8 exists" "pass" "" || check "Namespace lab-1-8 exists" "fail" "Run ./setup.sh"
kubectl get configmap binary-verification-results -n lab-1-8 &>/dev/null && check "ConfigMap binary-verification-results exists" "pass" "" || check "ConfigMap binary-verification-results exists" "fail" "Create the binary-verification-results ConfigMap"
kubectl get configmap verification-procedure -n lab-1-8 &>/dev/null && check "ConfigMap verification-procedure exists" "pass" "" || check "ConfigMap verification-procedure exists" "fail" "Create the verification-procedure ConfigMap"

SHA=$(kubectl get configmap binary-verification-results -n lab-1-8 -o jsonpath='{.data.sha256}' 2>/dev/null)
[ -n "$SHA" ] && check "binary-verification-results has sha256 field" "pass" "" || check "binary-verification-results has sha256 field" "fail" "Add sha256 field to the ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
