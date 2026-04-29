#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: NodeRestriction Admission Controller ===${NC}"
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$NODE" ] && kubectl label node "$NODE" security-zone- --ignore-not-found=true 2>/dev/null || true
kubectl delete configmap node-restriction-config node-labels-test -n lab-2-9 --ignore-not-found=true
kubectl delete namespace lab-2-9 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
