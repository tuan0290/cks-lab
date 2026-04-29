#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: ServiceAccount Token Management ===${NC}"
kubectl delete pod no-token-pod api-reader-pod -n lab-2-5 --ignore-not-found=true
kubectl delete rolebinding api-reader-binding -n lab-2-5 --ignore-not-found=true
kubectl delete role pod-reader -n lab-2-5 --ignore-not-found=true
kubectl delete serviceaccount no-token-sa api-reader-sa -n lab-2-5 --ignore-not-found=true
kubectl delete namespace lab-2-5 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
