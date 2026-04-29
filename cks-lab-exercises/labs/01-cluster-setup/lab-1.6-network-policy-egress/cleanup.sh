#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: NetworkPolicy Egress Control ===${NC}"
kubectl delete networkpolicy backend-egress -n lab-1-6 --ignore-not-found=true
kubectl delete pod backend database -n lab-1-6 --ignore-not-found=true
kubectl delete namespace lab-1-6 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
