#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Container Image Hardening ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete ClusterPolicy
    kubectl delete clusterpolicy enforce-container-hardening --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ClusterPolicy enforce-container-hardening deleted${NC}"

    # Delete Deployments
    kubectl delete deployment hardened-app -n lab-5-10 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete deployment unhardened-app -n lab-5-10 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Deployments deleted${NC}"

    # Delete ConfigMaps
    kubectl delete configmap hardening-checklist -n lab-5-10 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete configmap lab-instructions -n lab-5-10 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ConfigMaps deleted${NC}"

    # Delete namespace
    kubectl delete namespace lab-5-10 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-10 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
