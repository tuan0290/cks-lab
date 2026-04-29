#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Cấu hình etcd Encryption ===${NC}"
echo ""

# Delete resources
delete_resources() {
    echo "Deleting lab resources..."
    echo ""

    # Delete specific resources
    # Delete EncryptionConfiguration
    kubectl delete encryptionconfiguration --all -n lab-1-1 --ignore-not-found=true > /dev/null 2>&1 || true

    # Delete namespace
    kubectl delete namespace lab-1-1 --ignore-not-found=true > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-1-1 deleted${NC}"

    echo ""
}

# Main execution
delete_resources

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
