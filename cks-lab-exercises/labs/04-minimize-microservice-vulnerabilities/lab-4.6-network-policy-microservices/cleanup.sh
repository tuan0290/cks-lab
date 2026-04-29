#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}=== Lab Cleanup: NetworkPolicy for Microservices ===${NC}"
kubectl delete networkpolicy default-deny allow-frontend-to-backend allow-backend-to-database -n lab-4-6 --ignore-not-found=true
kubectl delete pod frontend backend database -n lab-4-6 --ignore-not-found=true
kubectl delete namespace lab-4-6 --ignore-not-found=true
echo -e "${GREEN}✓ Lab cleanup complete${NC}"
