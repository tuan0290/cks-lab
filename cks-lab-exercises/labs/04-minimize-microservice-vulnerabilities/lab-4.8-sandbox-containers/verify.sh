#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0
echo -e "${YELLOW}=== Lab Verification: Sandbox Containers ===${NC}"

check() {
    local desc="$1" result="$2" hint="$3"
    echo -n "Checking: $desc... "
    if [ "$result" = "pass" ]; then echo -e "${GREEN}✓ PASS${NC}"; ((PASSED++))
    else echo -e "${RED}✗ FAIL${NC}"; echo -e "  ${YELLOW}Hint: $hint${NC}"; ((FAILED++)); fi
}

kubectl get namespace lab-4-8 &>/dev/null && check "Namespace lab-4-8 exists" "pass" "" || check "Namespace lab-4-8 exists" "fail" "Run ./setup.sh"
kubectl get runtimeclass gvisor &>/dev/null && check "RuntimeClass gvisor exists" "pass" "" || check "RuntimeClass gvisor exists" "fail" "Create gvisor RuntimeClass"

HANDLER=$(kubectl get runtimeclass gvisor -o jsonpath='{.handler}' 2>/dev/null)
[ "$HANDLER" = "runsc" ] && check "RuntimeClass gvisor has handler: runsc" "pass" "" || check "RuntimeClass gvisor has handler: runsc" "fail" "Set handler: runsc in RuntimeClass"

kubectl get pod sandboxed-app -n lab-4-8 &>/dev/null && check "Pod sandboxed-app exists" "pass" "" || check "Pod sandboxed-app exists" "fail" "Create sandboxed-app pod (may be Pending if gVisor not installed)"

RUNTIME=$(kubectl get pod sandboxed-app -n lab-4-8 -o jsonpath='{.spec.runtimeClassName}' 2>/dev/null)
[ "$RUNTIME" = "gvisor" ] && check "Pod uses runtimeClassName: gvisor" "pass" "" || check "Pod uses runtimeClassName: gvisor" "fail" "Set spec.runtimeClassName: gvisor"

kubectl get configmap sandbox-comparison -n lab-4-8 &>/dev/null && check "ConfigMap sandbox-comparison exists" "pass" "" || check "ConfigMap sandbox-comparison exists" "fail" "Create sandbox-comparison ConfigMap"

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"; echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"
[ $FAILED -eq 0 ] && echo -e "${GREEN}✓ All checks passed!${NC}" && exit 0 || echo -e "${RED}✗ Some checks failed.${NC}" && exit 1
