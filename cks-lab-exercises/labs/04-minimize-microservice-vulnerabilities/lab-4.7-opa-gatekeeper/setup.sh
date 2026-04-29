#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${GREEN}=== Lab Setup: OPA Gatekeeper Policy Enforcement ===${NC}"
if ! command -v kubectl &>/dev/null; then echo -e "${RED}Error: kubectl not found${NC}"; exit 1; fi
if ! kubectl cluster-info &>/dev/null; then echo -e "${RED}Error: Cannot connect to cluster${NC}"; exit 1; fi
kubectl create namespace lab-4-7 --dry-run=client -o yaml | kubectl apply -f -
echo -e "${YELLOW}Note: This lab requires OPA Gatekeeper to be installed in the cluster${NC}"
echo -e "${YELLOW}Install: kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml${NC}"
echo -e "${GREEN}✓ Lab setup complete${NC}"
