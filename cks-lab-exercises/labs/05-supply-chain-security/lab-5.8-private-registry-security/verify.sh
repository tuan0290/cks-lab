#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Private Registry Security ===${NC}"
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
    "Namespace lab-5-8 exists" \
    "kubectl get namespace lab-5-8" \
    "lab-5-8" \
    "Run ./setup.sh to create the namespace"

check \
    "Secret registry-credentials exists" \
    "kubectl get secret registry-credentials -n lab-5-8" \
    "registry-credentials" \
    "Run: kubectl create secret docker-registry registry-credentials --docker-server=registry.example.com --docker-username=lab-user --docker-password=lab-password-secure --docker-email=lab@example.com -n lab-5-8"

check \
    "registry-credentials is of type docker-registry" \
    "kubectl get secret registry-credentials -n lab-5-8 -o jsonpath='{.type}'" \
    "dockerconfigjson" \
    "The secret must be of type kubernetes.io/dockerconfigjson"

check \
    "Default ServiceAccount has imagePullSecrets" \
    "kubectl get serviceaccount default -n lab-5-8 -o jsonpath='{.imagePullSecrets}'" \
    "registry-credentials" \
    "Patch the default SA: kubectl patch serviceaccount default -n lab-5-8 -p '{\"imagePullSecrets\": [{\"name\": \"registry-credentials\"}]}'"

check \
    "ClusterPolicy restrict-image-registries exists" \
    "kubectl get clusterpolicy restrict-image-registries" \
    "restrict-image-registries" \
    "Create a ClusterPolicy named 'restrict-image-registries'"

check \
    "restrict-image-registries has validate rule" \
    "kubectl get clusterpolicy restrict-image-registries -o jsonpath='{.spec.rules[0].validate}'" \
    "pattern" \
    "The policy should have a validate rule with a pattern for allowed registries"

check \
    "Deployment private-registry-app exists" \
    "kubectl get deployment private-registry-app -n lab-5-8" \
    "private-registry-app" \
    "Create a Deployment named 'private-registry-app'"

check \
    "private-registry-app has imagePullSecrets" \
    "kubectl get deployment private-registry-app -n lab-5-8 -o jsonpath='{.spec.template.spec.imagePullSecrets}'" \
    "registry-credentials" \
    "Add imagePullSecrets: [{name: registry-credentials}] to the pod spec"

check \
    "ServiceAccount app-service-account exists" \
    "kubectl get serviceaccount app-service-account -n lab-5-8" \
    "app-service-account" \
    "Create a ServiceAccount named 'app-service-account' with imagePullSecrets"

check \
    "app-service-account has imagePullSecrets" \
    "kubectl get serviceaccount app-service-account -n lab-5-8 -o jsonpath='{.imagePullSecrets}'" \
    "registry-credentials" \
    "Add imagePullSecrets: [{name: registry-credentials}] to the ServiceAccount"

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
