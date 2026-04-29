#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: CIS Benchmark with kube-bench ===${NC}"
echo ""

check() {
    local description="$1"
    local result="$2"
    local hint="$3"
    echo -n "Checking: $description... "
    if [ "$result" = "pass" ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "  ${YELLOW}Hint: $hint${NC}"
        ((FAILED++))
    fi
}

# Check 1: Namespace exists with correct label
if kubectl get namespace lab-1-4 --show-labels 2>/dev/null | grep -q "security=cis-benchmark"; then
    check "Namespace lab-1-4 exists with label security=cis-benchmark" "pass" ""
else
    check "Namespace lab-1-4 exists with label security=cis-benchmark" "fail" "Run: kubectl create namespace lab-1-4 && kubectl label namespace lab-1-4 security=cis-benchmark"
fi

# Check 2: ConfigMap cis-benchmark-results exists
if kubectl get configmap cis-benchmark-results -n lab-1-4 &>/dev/null; then
    check "ConfigMap cis-benchmark-results exists" "pass" ""
else
    check "ConfigMap cis-benchmark-results exists" "fail" "Create the cis-benchmark-results ConfigMap in namespace lab-1-4"
fi

# Check 3: ConfigMap cis-remediation-plan exists
if kubectl get configmap cis-remediation-plan -n lab-1-4 &>/dev/null; then
    check "ConfigMap cis-remediation-plan exists" "pass" ""
else
    check "ConfigMap cis-remediation-plan exists" "fail" "Create the cis-remediation-plan ConfigMap in namespace lab-1-4"
fi

# Check 4: Remediation plan has content
if kubectl get configmap cis-remediation-plan -n lab-1-4 -o jsonpath='{.data}' 2>/dev/null | grep -q "remediation"; then
    check "cis-remediation-plan has remediation content" "pass" ""
else
    check "cis-remediation-plan has remediation content" "fail" "Add remediation steps to the ConfigMap data"
fi

echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Review the hints above.${NC}"
    exit 1
fi
