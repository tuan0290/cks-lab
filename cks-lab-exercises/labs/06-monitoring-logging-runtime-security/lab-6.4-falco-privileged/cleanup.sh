#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Falco Custom Rules - Privileged Container Detection ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    kubectl delete pod privileged-test -n lab-6-4 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Privileged test pod deleted${NC}"

    kubectl delete pod normal-pod -n lab-6-4 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Normal pod deleted${NC}"

    kubectl delete pod priv-test-2 -n lab-6-4 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Additional test pods deleted${NC}"

    kubectl delete configmap falco-privileged-rules -n falco --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco privileged rules ConfigMap deleted${NC}"

    kubectl delete namespace lab-6-4 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-4 deleted${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
