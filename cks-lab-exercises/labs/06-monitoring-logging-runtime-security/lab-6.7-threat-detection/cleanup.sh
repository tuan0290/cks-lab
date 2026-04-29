#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Threat Detection ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    kubectl delete pod attacker-pod victim-app monitor-pod -n lab-6-7 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Test pods deleted${NC}"

    kubectl delete networkpolicy isolate-attacker -n lab-6-7 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Isolation NetworkPolicy deleted${NC}"

    kubectl delete configmap falco-threat-detection -n falco --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco threat detection ConfigMap deleted${NC}"

    kubectl delete namespace lab-6-7 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-7 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
