#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Network Traffic Monitoring and Anomaly Detection ===${NC}"
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
    "Namespace lab-6-11 exists" \
    "kubectl get namespace lab-6-11" \
    "lab-6-11" \
    "Run ./setup.sh to create the namespace"

check \
    "Network test pod exists" \
    "kubectl get pod network-test -n lab-6-11" \
    "network-test" \
    "Run ./setup.sh to create the test pod"

check \
    "Falco namespace exists" \
    "kubectl get namespace falco" \
    "falco" \
    "Create the falco namespace: kubectl create namespace falco"

check \
    "Falco network monitoring ConfigMap exists" \
    "kubectl get configmap falco-network-monitoring -n falco" \
    "falco-network-monitoring" \
    "Create ConfigMap: kubectl create configmap falco-network-monitoring --from-file=falco-network-monitoring-rules.yaml -n falco"

check \
    "ConfigMap contains external connection rule" \
    "kubectl get configmap falco-network-monitoring -n falco -o yaml" \
    "External.*Connection\|external.*network\|outbound.*container" \
    "Add a rule to detect connections to external (non-RFC1918) IP addresses"

check \
    "ConfigMap contains suspicious port rule" \
    "kubectl get configmap falco-network-monitoring -n falco -o yaml" \
    "Suspicious.*Port\|4444\|1337\|31337\|suspicious.*port" \
    "Add a rule to detect connections on suspicious ports (4444, 1337, etc.)"

check \
    "ConfigMap checks for non-RFC1918 addresses" \
    "kubectl get configmap falco-network-monitoring -n falco -o yaml" \
    "10\.0\.0\.0\|172\.16\.0\.0\|192\.168\.0\.0\|RFC1918\|private" \
    "Exclude RFC1918 private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)"

check \
    "Egress restriction NetworkPolicy exists" \
    "kubectl get networkpolicy restrict-egress -n lab-6-11" \
    "restrict-egress" \
    "Apply the restrict-egress NetworkPolicy (see README Step 5)"

check \
    "Egress policy allows DNS (port 53)" \
    "kubectl get networkpolicy restrict-egress -n lab-6-11 -o yaml" \
    "port: 53" \
    "Allow port 53 for DNS resolution in the egress policy"

check \
    "Egress policy restricts to internal traffic" \
    "kubectl get networkpolicy restrict-egress -n lab-6-11 -o yaml" \
    "namespaceSelector\|podSelector" \
    "Use namespaceSelector or podSelector to restrict egress to internal traffic only"

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
