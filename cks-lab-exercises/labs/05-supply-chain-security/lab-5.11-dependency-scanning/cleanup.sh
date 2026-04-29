#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Dependency Scanning with Trivy ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete Job
    kubectl delete job trivy-scanner -n lab-5-11 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Job trivy-scanner deleted${NC}"

    # Delete Deployment
    kubectl delete deployment scanned-app -n lab-5-11 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Deployment scanned-app deleted${NC}"

    # Delete ConfigMaps
    kubectl delete configmap scan-policy -n lab-5-11 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete configmap scan-results -n lab-5-11 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete configmap lab-instructions -n lab-5-11 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ConfigMaps deleted${NC}"

    # Delete namespace
    kubectl delete namespace lab-5-11 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-11 deleted${NC}"

    # Clean up local scan files
    rm -f /tmp/scan-results.json
    echo -e "${GREEN}✓ Local scan files cleaned up${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
