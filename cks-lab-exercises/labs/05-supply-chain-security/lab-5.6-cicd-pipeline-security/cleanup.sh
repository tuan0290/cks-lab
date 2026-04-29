#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: CI/CD Pipeline Security ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete Job
    kubectl delete job image-scanner -n lab-5-6 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Job image-scanner deleted${NC}"

    # Delete Deployments
    kubectl delete deployment pipeline-app -n lab-5-6 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete deployment unscanned-app -n lab-5-6 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Deployments deleted${NC}"

    # Delete RoleBinding and Role
    kubectl delete rolebinding cicd-deployer-binding -n lab-5-6 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete role cicd-deployer-role -n lab-5-6 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ RBAC resources deleted${NC}"

    # Delete ServiceAccount
    kubectl delete serviceaccount cicd-deployer -n lab-5-6 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ServiceAccount cicd-deployer deleted${NC}"

    # Delete ConfigMaps
    kubectl delete configmap pipeline-config -n lab-5-6 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete configmap lab-instructions -n lab-5-6 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ ConfigMaps deleted${NC}"

    # Delete namespace
    kubectl delete namespace lab-5-6 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-6 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
