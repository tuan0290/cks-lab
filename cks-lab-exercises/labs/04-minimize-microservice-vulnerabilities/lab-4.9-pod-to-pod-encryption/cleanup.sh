#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: Pod-to-Pod Encryption ===${NC}"
kubectl delete pod tls-server -n lab-4-9 --ignore-not-found=true
kubectl delete secret service-tls -n lab-4-9 --ignore-not-found=true
kubectl delete configmap mtls-config -n lab-4-9 --ignore-not-found=true
kubectl delete namespace lab-4-9 --ignore-not-found=true
rm -f /tmp/service.key /tmp/service.crt
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
