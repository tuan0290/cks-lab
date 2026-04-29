#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Dependency Scanning with Trivy ===${NC}"
echo ""

check() {
    local description="$1"
    local command="$2"
    local expected="$3"
    local hint="$4"

    echo -n "Checking: $description... "

    if eval "$command" 2>/dev/null | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        if [ -n "$hint" ]; then
            echo -e "  ${YELLOW}Hint: $hint${NC}"
        fi
        ((FAILED++))
    fi
}

# Verification checks

check \
    "Namespace lab-5-11 exists" \
    "kubectl get namespace lab-5-11" \
    "lab-5-11" \
    "Run ./setup.sh to create the namespace"

check \
    "ConfigMap scan-policy exists" \
    "kubectl get configmap scan-policy -n lab-5-11" \
    "scan-policy" \
    "Create a ConfigMap named 'scan-policy' with vulnerability thresholds"

check \
    "scan-policy has max-critical threshold" \
    "kubectl get configmap scan-policy -n lab-5-11 -o jsonpath='{.data.max-critical}'" \
    "0" \
    "Set max-critical: '0' in the scan-policy ConfigMap"

check \
    "scan-policy has block-on-critical setting" \
    "kubectl get configmap scan-policy -n lab-5-11 -o jsonpath='{.data.block-on-critical}'" \
    "true" \
    "Set block-on-critical: 'true' in the scan-policy ConfigMap"

check \
    "ConfigMap scan-results exists" \
    "kubectl get configmap scan-results -n lab-5-11" \
    "scan-results" \
    "Create a ConfigMap named 'scan-results' with scan findings"

check \
    "scan-results has scan tool annotation" \
    "kubectl get configmap scan-results -n lab-5-11 -o jsonpath='{.metadata.annotations}'" \
    "trivy" \
    "Add security.scan/tool: trivy annotation to the scan-results ConfigMap"

check \
    "Job trivy-scanner exists" \
    "kubectl get job trivy-scanner -n lab-5-11" \
    "trivy-scanner" \
    "Create a Job named 'trivy-scanner' that runs trivy image scan"

check \
    "trivy-scanner uses trivy image" \
    "kubectl get job trivy-scanner -n lab-5-11 -o jsonpath='{.spec.template.spec.containers[0].image}'" \
    "trivy" \
    "Use aquasec/trivy:latest as the container image for the scanner job"

check \
    "Deployment scanned-app exists" \
    "kubectl get deployment scanned-app -n lab-5-11" \
    "scanned-app" \
    "Create a Deployment named 'scanned-app'"

check \
    "scanned-app has scan status annotation" \
    "kubectl get deployment scanned-app -n lab-5-11 -o jsonpath='{.metadata.annotations}'" \
    "scan" \
    "Add security.scan/status annotation to the scanned-app deployment"

check \
    "scanned-app has scan tool annotation" \
    "kubectl get deployment scanned-app -n lab-5-11 -o jsonpath='{.metadata.annotations}'" \
    "trivy" \
    "Add security.scan/tool: trivy annotation to the scanned-app deployment"

# Summary
echo ""
echo "================================"
echo "Total checks: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "================================"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Review the hints above.${NC}"
    exit 1
fi
