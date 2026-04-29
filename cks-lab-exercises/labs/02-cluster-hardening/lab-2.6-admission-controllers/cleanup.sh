#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Admission Controllers Configuration ===${NC}"
kubectl delete namespace pss-test --ignore-not-found=true
kubectl delete configmap admission-controllers-config admission-test-results -n lab-2-6 --ignore-not-found=true
kubectl delete namespace lab-2-6 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
