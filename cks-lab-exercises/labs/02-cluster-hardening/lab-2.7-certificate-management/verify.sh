#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Certificate Management ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-2-7 &>/dev/null && check "Namespace lab-2-7 exists" "pass" "" || check "Namespace lab-2-7 exists" "fail" "Run ./setup.sh"
kubectl get csr dev-user-csr &>/dev/null && check "CertificateSigningRequest dev-user-csr exists" "pass" "" || check "CertificateSigningRequest dev-user-csr exists" "fail" "Create the CSR object (Step 3)"

CSR_STATUS=$(kubectl get csr dev-user-csr -o jsonpath='{.status.conditions[0].type}' 2>/dev/null)
[ "$CSR_STATUS" = "Approved" ] && check "CSR dev-user-csr is Approved" "pass" "" || check "CSR dev-user-csr is Approved" "fail" "Run: kubectl certificate approve dev-user-csr"

kubectl get configmap cert-expiry-report -n lab-2-7 &>/dev/null && check "ConfigMap cert-expiry-report exists" "pass" "" || check "ConfigMap cert-expiry-report exists" "fail" "Create cert-expiry-report ConfigMap"
kubectl get configmap csr-procedure -n lab-2-7 &>/dev/null && check "ConfigMap csr-procedure exists" "pass" "" || check "ConfigMap csr-procedure exists" "fail" "Create csr-procedure ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
