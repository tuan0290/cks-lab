#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: IAM Roles and Cloud Identity ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-3-6 &>/dev/null && check "Namespace lab-3-6 exists" "pass" "" || check "Namespace lab-3-6 exists" "fail" "Run ./setup.sh"
kubectl get serviceaccount cloud-access-sa -n lab-3-6 &>/dev/null && check "ServiceAccount cloud-access-sa exists" "pass" "" || check "ServiceAccount cloud-access-sa exists" "fail" "Create cloud-access-sa ServiceAccount"

SA_ANNOTATION=$(kubectl get serviceaccount cloud-access-sa -n lab-3-6 -o jsonpath='{.metadata.annotations}' 2>/dev/null)
[ -n "$SA_ANNOTATION" ] && check "ServiceAccount has workload identity annotation" "pass" "" || check "ServiceAccount has workload identity annotation" "fail" "Add workload identity annotation to ServiceAccount"

kubectl get pod cloud-app -n lab-3-6 &>/dev/null && check "Pod cloud-app exists" "pass" "" || check "Pod cloud-app exists" "fail" "Create cloud-app pod"
kubectl get networkpolicy block-metadata -n lab-3-6 &>/dev/null && check "NetworkPolicy block-metadata exists" "pass" "" || check "NetworkPolicy block-metadata exists" "fail" "Create block-metadata NetworkPolicy"
kubectl get configmap iam-best-practices -n lab-3-6 &>/dev/null && check "ConfigMap iam-best-practices exists" "pass" "" || check "ConfigMap iam-best-practices exists" "fail" "Create iam-best-practices ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
