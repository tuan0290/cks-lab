#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Secret Management ===${NC}"
kubectl delete pod app-pod -n lab-4-5 --ignore-not-found=true
kubectl delete rolebinding app-secret-binding -n lab-4-5 --ignore-not-found=true
kubectl delete role secret-reader -n lab-4-5 --ignore-not-found=true
kubectl delete serviceaccount app-sa -n lab-4-5 --ignore-not-found=true
kubectl delete secret db-credentials -n lab-4-5 --ignore-not-found=true
kubectl delete namespace lab-4-5 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
