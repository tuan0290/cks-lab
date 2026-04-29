#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Admission Controllers for Supply Chain Enforcement ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete ClusterPolicies
    kubectl delete clusterpolicy supply-chain-validate --ignore-not-found=true > /dev/null 2>&1
    kubectl delete clusterpolicy supply-chain-mutate --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ClusterPolicies deleted${NC}"

    # Delete Deployments
    kubectl delete deployment compliant-app -n lab-5-12 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete deployment non-compliant-app -n lab-5-12 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Deployments deleted${NC}"

    # Delete ConfigMaps
    kubectl delete configmap supply-chain-config -n lab-5-12 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete configmap lab-instructions -n lab-5-12 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ConfigMaps deleted${NC}"

    # Delete namespace
    kubectl delete namespace lab-5-12 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-12 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
