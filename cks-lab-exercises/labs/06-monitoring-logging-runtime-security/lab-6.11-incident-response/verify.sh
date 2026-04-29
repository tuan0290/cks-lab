#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Kubernetes Incident Response ===${NC}"
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

check_absent() {
    local description="$1"
    local command="$2"
    local absent="$3"
    local hint="$4"

    echo -n "Checking: $description... "

    if eval "$command" 2>/dev/null | grep -q "$absent"; then
        echo -e "${RED}✗ FAIL (resource still exists)${NC}"
        if [ -n "$hint" ]; then
            echo -e "  ${YELLOW}Hint: $hint${NC}"
        fi
        ((FAILED++))
    else
        echo -e "${GREEN}✓ PASS (resource removed)${NC}"
        ((PASSED++))
    fi
}

# Verification checks

check \
    "Namespace lab-6-11 exists" \
    "kubectl get namespace lab-6-11" \
    "lab-6-11" \
    "Run ./setup.sh to create the namespace"

echo ""
echo -e "${YELLOW}--- Containment Phase ---${NC}"

check \
    "Emergency isolation NetworkPolicy exists" \
    "kubectl get networkpolicy emergency-isolation -n lab-6-11" \
    "emergency-isolation" \
    "Apply the emergency isolation NetworkPolicy (see README Step 3)"

check \
    "Isolation policy blocks Ingress" \
    "kubectl get networkpolicy emergency-isolation -n lab-6-11 -o yaml" \
    "Ingress" \
    "Include Ingress in policyTypes of the isolation NetworkPolicy"

check \
    "Isolation policy blocks Egress" \
    "kubectl get networkpolicy emergency-isolation -n lab-6-11 -o yaml" \
    "Egress" \
    "Include Egress in policyTypes of the isolation NetworkPolicy"

check \
    "Isolation policy targets compromised pods" \
    "kubectl get networkpolicy emergency-isolation -n lab-6-11 -o yaml" \
    "compromised\|status" \
    "Use podSelector with matchLabels status: compromised"

echo ""
echo -e "${YELLOW}--- Eradication Phase ---${NC}"

check_absent \
    "Suspicious pod has been deleted" \
    "kubectl get pod suspicious-pod -n lab-6-11 2>&1" \
    "suspicious-pod" \
    "Delete the compromised pod: kubectl delete pod suspicious-pod -n lab-6-11"

echo ""
echo -e "${YELLOW}--- Recovery Phase ---${NC}"

check \
    "Clean replacement pod exists" \
    "kubectl get pod clean-replacement -n lab-6-11" \
    "clean-replacement" \
    "Deploy a clean replacement pod (see README Step 7)"

check \
    "Clean pod has readOnlyRootFilesystem" \
    "kubectl get pod clean-replacement -n lab-6-11 -o yaml" \
    "readOnlyRootFilesystem: true" \
    "Set readOnlyRootFilesystem: true in the clean replacement pod"

check \
    "Clean pod has allowPrivilegeEscalation: false" \
    "kubectl get pod clean-replacement -n lab-6-11 -o yaml" \
    "allowPrivilegeEscalation: false" \
    "Set allowPrivilegeEscalation: false in the clean replacement pod"

echo ""
echo -e "${YELLOW}--- Post-Incident Detection ---${NC}"

check \
    "Falco incident rules ConfigMap exists" \
    "kubectl get configmap falco-incident-rules -n falco" \
    "falco-incident-rules" \
    "Create the post-incident Falco rules ConfigMap (see README Step 8)"

check \
    "Falco rules detect K8s API access from containers" \
    "kubectl get configmap falco-incident-rules -n falco -o yaml" \
    "K8s API\|kubernetes.default\|6443\|api.*access" \
    "Add a rule to detect containers accessing the Kubernetes API server"

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
