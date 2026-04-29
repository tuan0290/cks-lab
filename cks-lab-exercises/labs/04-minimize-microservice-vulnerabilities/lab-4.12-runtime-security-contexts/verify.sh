#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Runtime Security ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-4-12 &>/dev/null && check "Namespace lab-4-12 exists" "pass" "" || check "Namespace lab-4-12 exists" "fail" "Run ./setup.sh"
kubectl get deployment immutable-app -n lab-4-12 &>/dev/null && check "Deployment immutable-app exists" "pass" "" || check "Deployment immutable-app exists" "fail" "Create immutable-app deployment"

RO_FS=$(kubectl get deployment immutable-app -n lab-4-12 -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)
[ "$RO_FS" = "true" ] && check "immutable-app has readOnlyRootFilesystem: true" "pass" "" || check "immutable-app has readOnlyRootFilesystem: true" "fail" "Set readOnlyRootFilesystem: true"

kubectl get configmap falco-microservice-rules -n lab-4-12 &>/dev/null && check "ConfigMap falco-microservice-rules exists" "pass" "" || check "ConfigMap falco-microservice-rules exists" "fail" "Create falco-microservice-rules ConfigMap"
kubectl get configmap runtime-security-policy -n lab-4-12 &>/dev/null && check "ConfigMap runtime-security-policy exists" "pass" "" || check "ConfigMap runtime-security-policy exists" "fail" "Create runtime-security-policy ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
