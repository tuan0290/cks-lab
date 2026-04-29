#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Runtime Immutability ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    kubectl delete pod immutable-pod mutable-pod -n lab-6-12 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Pods deleted${NC}"

    kubectl delete deployment immutable-deployment -n lab-6-12 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Deployment deleted${NC}"

    kubectl delete configmap falco-immutability-rules -n falco --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco rules ConfigMap deleted${NC}"

    kubectl delete namespace lab-6-12 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-12 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
