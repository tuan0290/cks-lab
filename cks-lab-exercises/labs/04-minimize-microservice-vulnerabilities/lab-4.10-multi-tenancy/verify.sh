#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Multi-Tenancy Isolation ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

for tenant in tenant-a tenant-b; do
    kubectl get namespace $tenant &>/dev/null && check "Namespace $tenant exists" "pass" "" || check "Namespace $tenant exists" "fail" "Create namespace $tenant"
    kubectl get resourcequota tenant-quota -n $tenant &>/dev/null && check "ResourceQuota in $tenant" "pass" "" || check "ResourceQuota in $tenant" "fail" "Create ResourceQuota in $tenant"
    kubectl get networkpolicy tenant-isolation -n $tenant &>/dev/null && check "NetworkPolicy in $tenant" "pass" "" || check "NetworkPolicy in $tenant" "fail" "Create NetworkPolicy in $tenant"
    kubectl get serviceaccount ${tenant}-user -n $tenant &>/dev/null && check "ServiceAccount ${tenant}-user exists" "pass" "" || check "ServiceAccount ${tenant}-user exists" "fail" "Create ${tenant}-user ServiceAccount"
done

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
