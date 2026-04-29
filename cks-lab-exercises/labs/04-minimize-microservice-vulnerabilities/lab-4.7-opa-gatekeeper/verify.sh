#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: OPA Gatekeeper Policy Enforcement ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-4-7 &>/dev/null && check "Namespace lab-4-7 exists" "pass" "" || check "Namespace lab-4-7 exists" "fail" "Run ./setup.sh"
kubectl get constrainttemplate k8srequiredlabels &>/dev/null && check "ConstraintTemplate k8srequiredlabels exists" "pass" "" || check "ConstraintTemplate k8srequiredlabels exists" "fail" "Create k8srequiredlabels ConstraintTemplate (requires Gatekeeper)"
kubectl get pod labeled-pod -n lab-4-7 &>/dev/null && check "Pod labeled-pod exists" "pass" "" || check "Pod labeled-pod exists" "fail" "Create labeled-pod with label app=my-app"

APP_LABEL=$(kubectl get pod labeled-pod -n lab-4-7 -o jsonpath='{.metadata.labels.app}' 2>/dev/null)
[ -n "$APP_LABEL" ] && check "Pod labeled-pod has app label" "pass" "" || check "Pod labeled-pod has app label" "fail" "Add label app: my-app to labeled-pod"

kubectl get configmap gatekeeper-policy-docs -n lab-4-7 &>/dev/null && check "ConfigMap gatekeeper-policy-docs exists" "pass" "" || check "ConfigMap gatekeeper-policy-docs exists" "fail" "Create gatekeeper-policy-docs ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
