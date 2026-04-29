#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Lab Cleanup: Ingress TLS Configuration ===${NC}"
echo ""

echo "Deleting lab resources..."
kubectl delete ingress web-app-ingress -n lab-1-5 --ignore-not-found=true
kubectl delete service web-app-svc -n lab-1-5 --ignore-not-found=true
kubectl delete deployment web-app -n lab-1-5 --ignore-not-found=true
kubectl delete secret app-tls-secret -n lab-1-5 --ignore-not-found=true
kubectl delete namespace lab-1-5 --ignore-not-found=true
rm -f /tmp/tls.crt /tmp/tls.key

echo ""
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
