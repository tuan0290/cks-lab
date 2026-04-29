#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Container Behavior Analysis ===${NC}"
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
    "Namespace lab-6-10 exists" \
    "kubectl get namespace lab-6-10" \
    "lab-6-10" \
    "Run ./setup.sh to create the namespace"

check \
    "Behavior test pod exists" \
    "kubectl get pod behavior-test -n lab-6-10" \
    "behavior-test" \
    "Run ./setup.sh to create the test pod"

check \
    "Falco namespace exists" \
    "kubectl get namespace falco" \
    "falco" \
    "Create the falco namespace: kubectl create namespace falco"

check \
    "Falco behavior rules ConfigMap exists" \
    "kubectl get configmap falco-behavior-rules -n falco" \
    "falco-behavior-rules" \
    "Create ConfigMap: kubectl create configmap falco-behavior-rules --from-file=falco-behavior-rules.yaml -n falco"

check \
    "ConfigMap contains process execution rule" \
    "kubectl get configmap falco-behavior-rules -n falco -o yaml" \
    "spawned_process\|Process.*Execution\|Container Process" \
    "Add a rule to track process executions in containers"

check \
    "ConfigMap contains network connection rule" \
    "kubectl get configmap falco-behavior-rules -n falco -o yaml" \
    "outbound\|Network.*Connection\|Container Network" \
    "Add a rule to track network connections from containers"

check \
    "ConfigMap contains anomalous file access rule" \
    "kubectl get configmap falco-behavior-rules -n falco -o yaml" \
    "Anomalous\|open_read.*etc\|file.*access" \
    "Add a rule to detect anomalous file access patterns"

check \
    "ConfigMap contains crypto mining detection rule" \
    "kubectl get configmap falco-behavior-rules -n falco -o yaml" \
    "mining\|xmrig\|crypto\|Crypto" \
    "Add a rule to detect crypto mining indicators"

check \
    "Rules include pod and namespace context in output" \
    "kubectl get configmap falco-behavior-rules -n falco -o yaml" \
    "k8s.pod.name\|k8s.ns.name\|pod=%k8s" \
    "Include %k8s.pod.name and %k8s.ns.name in rule output for context"

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
