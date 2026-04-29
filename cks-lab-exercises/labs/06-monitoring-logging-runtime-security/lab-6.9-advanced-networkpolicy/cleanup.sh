#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Advanced NetworkPolicy ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete NetworkPolicies
    kubectl delete networkpolicy default-deny-all -n lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete networkpolicy allow-dns -n lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete networkpolicy allow-frontend-ingress -n lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete networkpolicy allow-frontend-to-backend -n lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete networkpolicy allow-frontend-egress-backend -n lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete networkpolicy allow-backend-to-database -n lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    kubectl delete networkpolicy allow-backend-egress-database -n lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ NetworkPolicies deleted${NC}"

    # Delete deployments and services
    kubectl delete deployment frontend backend database -n lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Deployments deleted${NC}"

    kubectl delete service frontend-svc backend-svc database-svc -n lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Services deleted${NC}"

    # Delete namespace
    kubectl delete namespace lab-6-9 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-9 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
