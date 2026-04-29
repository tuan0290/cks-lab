#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Certificate Management ===${NC}"
kubectl delete csr dev-user-csr --ignore-not-found=true
kubectl delete configmap cert-expiry-report csr-procedure -n lab-2-7 --ignore-not-found=true
kubectl delete namespace lab-2-7 --ignore-not-found=true
rm -f /tmp/dev-user.key /tmp/dev-user.csr /tmp/dev-user.crt
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
