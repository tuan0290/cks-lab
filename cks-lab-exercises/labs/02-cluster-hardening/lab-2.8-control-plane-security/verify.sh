#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Control Plane Security Hardening ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-2-8 &>/dev/null && check "Namespace lab-2-8 exists" "pass" "" || check "Namespace lab-2-8 exists" "fail" "Run ./setup.sh"
kubectl get configmap apiserver-security-config -n lab-2-8 &>/dev/null && check "ConfigMap apiserver-security-config exists" "pass" "" || check "ConfigMap apiserver-security-config exists" "fail" "Create apiserver-security-config ConfigMap"
kubectl get configmap etcd-security-config -n lab-2-8 &>/dev/null && check "ConfigMap etcd-security-config exists" "pass" "" || check "ConfigMap etcd-security-config exists" "fail" "Create etcd-security-config ConfigMap"
kubectl get configmap control-plane-audit -n lab-2-8 &>/dev/null && check "ConfigMap control-plane-audit exists" "pass" "" || check "ConfigMap control-plane-audit exists" "fail" "Create control-plane-audit ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
