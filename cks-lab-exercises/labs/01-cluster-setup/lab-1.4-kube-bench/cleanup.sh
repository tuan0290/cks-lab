#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: CIS Benchmark with kube-bench ===${NC}"
echo ""

echo "Deleting lab resources..."
kubectl delete job kube-bench -n lab-1-4 --ignore-not-found=true
kubectl delete configmap cis-benchmark-results cis-remediation-plan -n lab-1-4 --ignore-not-found=true
kubectl delete namespace lab-1-4 --ignore-not-found=true

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
