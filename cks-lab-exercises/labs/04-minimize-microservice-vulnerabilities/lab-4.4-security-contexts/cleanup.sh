#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Security Contexts ===${NC}"
kubectl delete pod secure-app multi-container-app -n lab-4-4 --ignore-not-found=true
kubectl delete namespace lab-4-4 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
