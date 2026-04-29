#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${GREEN}=== Lab Setup: NetworkPolicy for Microservices ===${NC}"
if ! command -v kubectl &>/dev/null; then echo -e "${RED}Error: kubectl not found${NC}"; exit 1; fi
if ! kubectl cluster-info &>/dev/null; then echo -e "${RED}Error: Cannot connect to cluster${NC}"; exit 1; fi
kubectl create namespace lab-4-6 --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Lab setup complete${NC}"
