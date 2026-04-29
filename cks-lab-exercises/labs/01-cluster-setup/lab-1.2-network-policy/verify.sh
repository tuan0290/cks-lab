#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: NetworkPolicy - Deny All Ingress ===${NC}"
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
    "Namespace lab-1-2 exists" \
    "kubectl get namespace lab-1-2" \
    "lab-1-2" \
    "Create the namespace first"

check \
    "NetworkPolicy default-deny-ingress exists" \
    "kubectl get networkpolicy default-deny-ingress -n lab-1-2" \
    "default-deny-ingress" \
    "Create the NetworkPolicy resource"

check \
    "NetworkPolicy allow-frontend-to-backend exists" \
    "kubectl get networkpolicy allow-frontend-to-backend -n lab-1-2" \
    "allow-frontend-to-backend" \
    "Create the NetworkPolicy resource"


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
