#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Runtime Security ===${NC}"
kubectl delete deployment immutable-app -n lab-4-12 --ignore-not-found=true
kubectl delete configmap falco-microservice-rules runtime-security-policy -n lab-4-12 --ignore-not-found=true
kubectl delete namespace lab-4-12 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
