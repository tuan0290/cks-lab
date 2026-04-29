#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Private Registry Security ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete ClusterPolicy
    kubectl delete clusterpolicy restrict-image-registries --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ClusterPolicy restrict-image-registries deleted${NC}"

    # Delete Deployment
    kubectl delete deployment private-registry-app -n lab-5-8 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Deployment private-registry-app deleted${NC}"

    # Delete ServiceAccount
    kubectl delete serviceaccount app-service-account -n lab-5-8 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ServiceAccount app-service-account deleted${NC}"

    # Delete Secret
    kubectl delete secret registry-credentials -n lab-5-8 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Secret registry-credentials deleted${NC}"

    # Delete ConfigMaps
    kubectl delete configmap lab-instructions -n lab-5-8 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ConfigMaps deleted${NC}"

    # Delete namespace
    kubectl delete namespace lab-5-8 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-8 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
