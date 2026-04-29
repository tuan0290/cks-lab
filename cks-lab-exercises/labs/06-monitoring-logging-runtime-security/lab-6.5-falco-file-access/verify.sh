#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Falco Custom Rules - Sensitive File Access ===${NC}"
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

# Check function for command success (exit code)
check_cmd() {
    local description="$1"
    local command="$2"
    local hint="$3"

    echo -n "Checking: $description... "

    if eval "$command" > /dev/null 2>&1; then
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
    "Namespace lab-6-5 exists" \
    "kubectl get namespace lab-6-5" \
    "lab-6-5" \
    "Run ./setup.sh to create the namespace"

check \
    "Test pod file-access-test is running" \
    "kubectl get pod file-access-test -n lab-6-5 -o jsonpath='{.status.phase}'" \
    "Running" \
    "Run ./setup.sh to create the test pod"

check \
    "Falco namespace exists" \
    "kubectl get namespace falco" \
    "falco" \
    "Create the falco namespace: kubectl create namespace falco"

check \
    "Falco custom rules ConfigMap exists in falco namespace" \
    "kubectl get configmap falco-file-access-rules -n falco" \
    "falco-file-access-rules" \
    "Create the ConfigMap: kubectl create configmap falco-file-access-rules --from-file=falco-file-access-rules.yaml -n falco"

check \
    "ConfigMap contains sensitive file access rule" \
    "kubectl get configmap falco-file-access-rules -n falco -o yaml" \
    "Detect Sensitive File Access" \
    "Ensure your ConfigMap contains a rule named 'Detect Sensitive File Access'"

check \
    "Rule monitors /etc/shadow" \
    "kubectl get configmap falco-file-access-rules -n falco -o yaml" \
    "/etc/shadow" \
    "Add /etc/shadow to the rule's condition fd.name list"

check \
    "Rule monitors /etc/passwd" \
    "kubectl get configmap falco-file-access-rules -n falco -o yaml" \
    "/etc/passwd" \
    "Add /etc/passwd to the rule's condition fd.name list"

check \
    "Rule has WARNING or higher priority" \
    "kubectl get configmap falco-file-access-rules -n falco -o yaml" \
    "WARNING\|CRITICAL\|ERROR" \
    "Set priority to WARNING, CRITICAL, or ERROR in your Falco rule"

check \
    "Rule output includes user name field" \
    "kubectl get configmap falco-file-access-rules -n falco -o yaml" \
    "user.name\|user=%user" \
    "Include %user.name in the rule output field"

check \
    "Rule output includes process command line" \
    "kubectl get configmap falco-file-access-rules -n falco -o yaml" \
    "proc.cmdline\|command=%proc" \
    "Include %proc.cmdline in the rule output field"

check \
    "Rule excludes legitimate processes" \
    "kubectl get configmap falco-file-access-rules -n falco -o yaml" \
    "sshd\|login\|systemd-logind" \
    "Add exclusions for sshd, login, systemd-logind in the rule condition"

# Check if Falco is running (optional - may not be installed)
echo ""
echo -e "${YELLOW}--- Optional Checks (require Falco to be running) ---${NC}"

check \
    "Falco DaemonSet exists" \
    "kubectl get daemonset -n falco" \
    "falco" \
    "Install Falco: helm install falco falcosecurity/falco -n falco --create-namespace"

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
