#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Minimizing Host OS Footprint ===${NC}"
kubectl delete clusterpolicy restrict-host-access --ignore-not-found=true
kubectl delete pod secure-pod -n lab-3-5 --ignore-not-found=true
kubectl delete configmap host-footprint-checklist -n lab-3-5 --ignore-not-found=true
kubectl delete namespace lab-3-5 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
