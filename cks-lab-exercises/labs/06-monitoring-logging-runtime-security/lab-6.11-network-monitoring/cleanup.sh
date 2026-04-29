#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Network Traffic Monitoring ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    kubectl delete pod network-test internal-server -n lab-6-11 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Pods deleted${NC}"

    kubectl delete service internal-svc -n lab-6-11 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Services deleted${NC}"

    kubectl delete networkpolicy restrict-egress -n lab-6-11 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ NetworkPolicies deleted${NC}"

    kubectl delete configmap falco-network-monitoring -n falco --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco network monitoring ConfigMap deleted${NC}"

    kubectl delete namespace lab-6-11 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-11 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
