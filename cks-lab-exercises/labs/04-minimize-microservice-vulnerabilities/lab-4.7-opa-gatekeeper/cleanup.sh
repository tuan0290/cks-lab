#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: OPA Gatekeeper Policy Enforcement ===${NC}"
kubectl delete k8srequiredlabels require-app-label --ignore-not-found=true 2>/dev/null || true
kubectl delete constrainttemplate k8srequiredlabels --ignore-not-found=true 2>/dev/null || true
kubectl delete pod labeled-pod -n lab-4-7 --ignore-not-found=true
kubectl delete configmap gatekeeper-policy-docs -n lab-4-7 --ignore-not-found=true
kubectl delete namespace lab-4-7 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
