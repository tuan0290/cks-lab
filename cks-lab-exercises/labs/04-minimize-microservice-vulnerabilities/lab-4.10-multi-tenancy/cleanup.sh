#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Multi-Tenancy Isolation ===${NC}"
kubectl delete namespace tenant-a tenant-b --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
