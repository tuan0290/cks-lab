#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: CI/CD Pipeline Security ===${NC}"
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
    "Namespace lab-5-6 exists" \
    "kubectl get namespace lab-5-6" \
    "lab-5-6" \
    "Run ./setup.sh to create the namespace"

check \
    "ServiceAccount cicd-deployer exists" \
    "kubectl get serviceaccount cicd-deployer -n lab-5-6" \
    "cicd-deployer" \
    "Create: kubectl create serviceaccount cicd-deployer -n lab-5-6"

check \
    "Role cicd-deployer-role exists" \
    "kubectl get role cicd-deployer-role -n lab-5-6" \
    "cicd-deployer-role" \
    "Create a Role with minimal deployment permissions"

check \
    "Role has deployments permission" \
    "kubectl get role cicd-deployer-role -n lab-5-6 -o jsonpath='{.rules[*].resources}'" \
    "deployments" \
    "The role should include 'deployments' in its resources"

check \
    "RoleBinding cicd-deployer-binding exists" \
    "kubectl get rolebinding cicd-deployer-binding -n lab-5-6" \
    "cicd-deployer-binding" \
    "Create a RoleBinding binding cicd-deployer-role to cicd-deployer ServiceAccount"

check \
    "RoleBinding references cicd-deployer ServiceAccount" \
    "kubectl get rolebinding cicd-deployer-binding -n lab-5-6 -o jsonpath='{.subjects[0].name}'" \
    "cicd-deployer" \
    "The RoleBinding should reference the cicd-deployer ServiceAccount"

check \
    "ConfigMap pipeline-config exists" \
    "kubectl get configmap pipeline-config -n lab-5-6" \
    "pipeline-config" \
    "Create a ConfigMap named 'pipeline-config' with scan thresholds"

check \
    "pipeline-config has scan severity threshold" \
    "kubectl get configmap pipeline-config -n lab-5-6 -o jsonpath='{.data.scan-severity-threshold}'" \
    "CRITICAL" \
    "Set scan-severity-threshold: CRITICAL in the pipeline-config ConfigMap"

check \
    "Job image-scanner exists" \
    "kubectl get job image-scanner -n lab-5-6" \
    "image-scanner" \
    "Create a Job named 'image-scanner' that runs trivy scan"

check \
    "Deployment pipeline-app exists" \
    "kubectl get deployment pipeline-app -n lab-5-6" \
    "pipeline-app" \
    "Create a Deployment named 'pipeline-app'"

check \
    "pipeline-app uses cicd-deployer service account" \
    "kubectl get deployment pipeline-app -n lab-5-6 -o jsonpath='{.spec.template.spec.serviceAccountName}'" \
    "cicd-deployer" \
    "Set serviceAccountName: cicd-deployer in the deployment spec"

check \
    "pipeline-app has scan status annotation" \
    "kubectl get deployment pipeline-app -n lab-5-6 -o jsonpath='{.metadata.annotations}'" \
    "scan" \
    "Add security.scan/status annotation to the deployment"

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
