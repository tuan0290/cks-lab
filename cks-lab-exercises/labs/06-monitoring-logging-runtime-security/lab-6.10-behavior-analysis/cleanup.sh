#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Container Behavior Analysis ===${NC}"
echo ""

delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    kubectl delete pod behavior-test webapp -n lab-6-10 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Test pods deleted${NC}"

    kubectl delete configmap falco-behavior-rules -n falco --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco behavior rules ConfigMap deleted${NC}"

    kubectl delete namespace lab-6-10 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-10 deleted${NC}"

    # Clean up temp files
    rm -f /tmp/falco-events.log 2>/dev/null || true
    echo -e "${GREEN}✓ Temporary files cleaned up${NC}"

    echo ""
}

delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
