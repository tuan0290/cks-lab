#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Falco Custom Rules - Sensitive File Access ===${NC}"
echo ""

# Delete resources
delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete test pods
    kubectl delete pod file-access-test -n lab-6-3 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Test pod deleted${NC}"

    kubectl delete pod legitimate-app -n lab-6-3 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Legitimate app pod deleted${NC}"

    # Delete the custom rules ConfigMap from falco namespace
    kubectl delete configmap falco-file-access-rules -n falco --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco custom rules ConfigMap deleted${NC}"

    # Delete the lab namespace
    kubectl delete namespace lab-6-3 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-3 deleted${NC}"

    echo ""
}

# Main execution
delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
echo ""
echo -e "${YELLOW}Note: Falco DaemonSet and its namespace were NOT deleted.${NC}"
echo "If you want to remove the custom rules from Falco, restart the DaemonSet:"
echo "  kubectl rollout restart daemonset/falco -n falco"
