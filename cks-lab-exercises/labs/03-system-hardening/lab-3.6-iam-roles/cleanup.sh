#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: IAM Roles and Cloud Identity ===${NC}"
kubectl delete networkpolicy block-metadata -n lab-3-6 --ignore-not-found=true
kubectl delete pod cloud-app -n lab-3-6 --ignore-not-found=true
kubectl delete serviceaccount cloud-access-sa -n lab-3-6 --ignore-not-found=true
kubectl delete configmap iam-best-practices -n lab-3-6 --ignore-not-found=true
kubectl delete namespace lab-3-6 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
