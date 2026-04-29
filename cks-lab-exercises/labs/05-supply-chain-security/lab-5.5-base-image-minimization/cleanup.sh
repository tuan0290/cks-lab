#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Base Image Minimization ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete Kyverno policy if it exists
    kubectl delete clusterpolicy restrict-base-images --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ClusterPolicy restrict-base-images deleted${NC}"

    # Delete pod
    kubectl delete pod minimal-alpine-pod -n lab-5-5 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Pod minimal-alpine-pod deleted${NC}"

    # Delete deployments
    kubectl delete deployment distroless-app -n lab-5-5 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete deployment full-image-app -n lab-5-5 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Deployments deleted${NC}"

    # Delete ConfigMaps
    kubectl delete configmap multistage-dockerfile -n lab-5-5 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete configmap lab-instructions -n lab-5-5 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ConfigMaps deleted${NC}"

    # Delete namespace
    kubectl delete namespace lab-5-5 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-5 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
