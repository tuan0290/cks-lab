#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Sandbox Containers ===${NC}"
kubectl delete pod sandboxed-app -n lab-4-8 --ignore-not-found=true
kubectl delete runtimeclass gvisor --ignore-not-found=true
kubectl delete configmap sandbox-comparison -n lab-4-8 --ignore-not-found=true
kubectl delete namespace lab-4-8 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
