#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Kubernetes Binary Verification ===${NC}"
kubectl delete configmap binary-verification-results verification-procedure -n lab-1-8 --ignore-not-found=true
kubectl delete namespace lab-1-8 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
