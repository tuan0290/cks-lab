#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Admission Controllers Configuration ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-2-6 &>/dev/null && check "Namespace lab-2-6 exists" "pass" "" || check "Namespace lab-2-6 exists" "fail" "Run ./setup.sh"
kubectl get configmap admission-controllers-config -n lab-2-6 &>/dev/null && check "ConfigMap admission-controllers-config exists" "pass" "" || check "ConfigMap admission-controllers-config exists" "fail" "Create admission-controllers-config ConfigMap"
kubectl get configmap admission-test-results -n lab-2-6 &>/dev/null && check "ConfigMap admission-test-results exists" "pass" "" || check "ConfigMap admission-test-results exists" "fail" "Create admission-test-results ConfigMap"

PSS_LABEL=$(kubectl get namespace pss-test -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
[ "$PSS_LABEL" = "restricted" ] && check "Namespace pss-test has PodSecurity enforce=restricted label" "pass" "" || check "Namespace pss-test has PodSecurity enforce=restricted label" "fail" "Create pss-test namespace with pod-security.kubernetes.io/enforce: restricted"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
