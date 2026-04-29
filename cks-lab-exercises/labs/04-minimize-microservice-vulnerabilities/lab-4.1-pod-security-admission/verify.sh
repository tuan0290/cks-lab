#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Pod Security Admission (PSA) — Thay thế PSP ===${NC}"
echo ""

# Check function
check() {
    local description="$1"
    local command="$2"
    local expected="$3"
    local hint="$4"

    echo -n "Checking: $description... "

    if eval "$command" 2>/dev/null | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        if [ -n "$hint" ]; then
            echo -e "  ${YELLOW}Hint: $hint${NC}"
        fi
        ((FAILED++))
    fi
}

# Verification checks

check \
    "Namespace lab-4-1 exists" \
    "kubectl get namespace lab-4-1" \
    "lab-4-1" \
    "Create the namespace first"

check \
    "Unknown baseline-ns exists" \
    "kubectl get unknown baseline-ns -n lab-4-1" \
    "baseline-ns" \
    "Create the Unknown resource"

check \
    "Pod restricted-pod exists" \
    "kubectl get pod restricted-pod -n lab-4-1" \
    "restricted-pod" \
    "Create the Pod resource"


# Summary
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
