#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Cosign Verification with Kyverno verifyImages ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete ClusterPolicies
    kubectl delete clusterpolicy verify-image-signatures --ignore-not-found=true > /dev/null 2>&1
    kubectl delete clusterpolicy audit-image-signatures --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ClusterPolicies deleted${NC}"

    # Delete Deployment
    kubectl delete deployment verified-app -n lab-5-7 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Deployment verified-app deleted${NC}"

    # Delete ConfigMaps
    kubectl delete configmap cosign-public-key -n lab-5-7 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete configmap cosign-key-placeholder -n lab-5-7 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete configmap lab-instructions -n lab-5-7 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ConfigMaps deleted${NC}"

    # Delete namespace
    kubectl delete namespace lab-5-7 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-7 deleted${NC}"

    # Clean up local key files if they exist
    if [ -f "cosign.key" ]; then
        rm -f cosign.key cosign.pub
        echo -e "${GREEN}✓ Local key files removed${NC}"
    fi

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
