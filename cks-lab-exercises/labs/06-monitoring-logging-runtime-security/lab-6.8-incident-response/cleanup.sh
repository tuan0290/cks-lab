#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Kubernetes Incident Response ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    kubectl delete pod suspicious-pod legitimate-pod clean-replacement -n lab-6-8 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Pods deleted${NC}"

    kubectl delete networkpolicy emergency-isolation -n lab-6-8 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ NetworkPolicies deleted${NC}"

    kubectl delete rolebinding compromised-binding -n lab-6-8 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete role overprivileged-role -n lab-6-8 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete serviceaccount compromised-sa -n lab-6-8 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ RBAC resources deleted${NC}"

    kubectl delete configmap falco-incident-rules -n falco --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco incident rules deleted${NC}"

    kubectl delete namespace lab-6-8 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-8 deleted${NC}"

    # Clean up temp files
    rm -f /tmp/incident-evidence.txt 2>/dev/null || true
    echo -e "${GREEN}✓ Temporary files cleaned up${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
