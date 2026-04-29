#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Control Plane Security Hardening ===${NC}"
kubectl delete configmap apiserver-security-config etcd-security-config control-plane-audit -n lab-2-8 --ignore-not-found=true
kubectl delete namespace lab-2-8 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
