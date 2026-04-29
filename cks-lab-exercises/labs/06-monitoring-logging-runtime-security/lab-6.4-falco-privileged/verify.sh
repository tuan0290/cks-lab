#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Falco Custom Rules - Privileged Container Detection ===${NC}"
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

# Verification checks

check \
    "Namespace lab-6-4 exists" \
    "kubectl get namespace lab-6-4" \
    "lab-6-4" \
    "Run ./setup.sh to create the namespace"

check \
    "Privileged test pod exists" \
    "kubectl get pod privileged-test -n lab-6-4" \
    "privileged-test" \
    "Run ./setup.sh to create the test pod"

check \
    "Falco namespace exists" \
    "kubectl get namespace falco" \
    "falco" \
    "Create the falco namespace: kubectl create namespace falco"

check \
    "Falco privileged rules ConfigMap exists" \
    "kubectl get configmap falco-privileged-rules -n falco" \
    "falco-privileged-rules" \
    "Create ConfigMap: kubectl create configmap falco-privileged-rules --from-file=falco-privileged-rules.yaml -n falco"

check \
    "ConfigMap contains privileged container rule" \
    "kubectl get configmap falco-privileged-rules -n falco -o yaml" \
    "Detect Privileged Container\|privileged" \
    "Ensure your ConfigMap contains a rule for privileged container detection"

check \
    "Rule checks container.privileged field" \
    "kubectl get configmap falco-privileged-rules -n falco -o yaml" \
    "container.privileged" \
    "Use 'container.privileged=true' in your rule condition"

check \
    "Rule has WARNING or higher priority" \
    "kubectl get configmap falco-privileged-rules -n falco -o yaml" \
    "WARNING\|CRITICAL\|ERROR" \
    "Set priority to WARNING or higher in your Falco rule"

check \
    "Rule output includes container name" \
    "kubectl get configmap falco-privileged-rules -n falco -o yaml" \
    "container.name\|container=%container" \
    "Include %container.name in the rule output field"

check \
    "Rule output includes image information" \
    "kubectl get configmap falco-privileged-rules -n falco -o yaml" \
    "container.image\|image=%container.image" \
    "Include %container.image.repository in the rule output field"

check \
    "Rule has exclusions for known privileged containers" \
    "kubectl get configmap falco-privileged-rules -n falco -o yaml" \
    "known_privileged_containers\|falco\|calico\|cilium" \
    "Add a macro or condition to exclude known legitimate privileged containers"

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
