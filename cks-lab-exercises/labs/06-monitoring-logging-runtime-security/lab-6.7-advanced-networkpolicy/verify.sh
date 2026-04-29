#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Advanced NetworkPolicy - Multi-Tier Isolation ===${NC}"
echo ""

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

check_count() {
    local description="$1"
    local command="$2"
    local min_count="$3"
    local hint="$4"

    echo -n "Checking: $description... "

    local count
    count=$(eval "$command" 2>/dev/null | wc -l)
    if [ "$count" -ge "$min_count" ]; then
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
    "Namespace lab-6-7 exists" \
    "kubectl get namespace lab-6-7" \
    "lab-6-7" \
    "Run ./setup.sh to create the namespace"

check \
    "Frontend deployment exists" \
    "kubectl get deployment frontend -n lab-6-7" \
    "frontend" \
    "Run ./setup.sh to create the frontend deployment"

check \
    "Backend deployment exists" \
    "kubectl get deployment backend -n lab-6-7" \
    "backend" \
    "Run ./setup.sh to create the backend deployment"

check \
    "Database deployment exists" \
    "kubectl get deployment database -n lab-6-7" \
    "database" \
    "Run ./setup.sh to create the database deployment"

check \
    "Default-deny-all NetworkPolicy exists" \
    "kubectl get networkpolicy default-deny-all -n lab-6-7" \
    "default-deny-all" \
    "Apply the default-deny-all NetworkPolicy (see README Step 3)"

check \
    "Default-deny-all policy has empty podSelector" \
    "kubectl get networkpolicy default-deny-all -n lab-6-7 -o yaml" \
    "podSelector: {}" \
    "Use 'podSelector: {}' to select all pods"

check \
    "Default-deny-all policy blocks both Ingress and Egress" \
    "kubectl get networkpolicy default-deny-all -n lab-6-7 -o yaml" \
    "Ingress" \
    "Include both Ingress and Egress in policyTypes"

check \
    "DNS allow policy exists" \
    "kubectl get networkpolicy allow-dns -n lab-6-7" \
    "allow-dns" \
    "Apply the allow-dns NetworkPolicy (see README Step 4)"

check \
    "DNS policy allows port 53 UDP" \
    "kubectl get networkpolicy allow-dns -n lab-6-7 -o yaml" \
    "port: 53" \
    "Allow port 53 for DNS resolution"

check \
    "Frontend ingress policy exists" \
    "kubectl get networkpolicy allow-frontend-ingress -n lab-6-7" \
    "allow-frontend-ingress" \
    "Apply the allow-frontend-ingress NetworkPolicy (see README Step 5)"

check \
    "Frontend ingress policy targets frontend tier" \
    "kubectl get networkpolicy allow-frontend-ingress -n lab-6-7 -o yaml" \
    "tier: frontend" \
    "Use podSelector with matchLabels tier: frontend"

check \
    "Frontend-to-backend policy exists" \
    "kubectl get networkpolicy allow-frontend-to-backend -n lab-6-7" \
    "allow-frontend-to-backend" \
    "Apply the allow-frontend-to-backend NetworkPolicy (see README Step 6)"

check \
    "Backend policy allows port 8080 from frontend" \
    "kubectl get networkpolicy allow-frontend-to-backend -n lab-6-7 -o yaml" \
    "8080" \
    "Allow port 8080 in the backend NetworkPolicy"

check \
    "Backend-to-database policy exists" \
    "kubectl get networkpolicy allow-backend-to-database -n lab-6-7" \
    "allow-backend-to-database" \
    "Apply the allow-backend-to-database NetworkPolicy (see README Step 7)"

check \
    "Database policy allows port 5432 from backend" \
    "kubectl get networkpolicy allow-backend-to-database -n lab-6-7 -o yaml" \
    "5432" \
    "Allow port 5432 in the database NetworkPolicy"

check_count \
    "At least 5 NetworkPolicies exist in namespace" \
    "kubectl get networkpolicy -n lab-6-7 --no-headers" \
    5 \
    "Create all required NetworkPolicies (default-deny, dns, frontend, frontend-backend, backend-database)"

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
