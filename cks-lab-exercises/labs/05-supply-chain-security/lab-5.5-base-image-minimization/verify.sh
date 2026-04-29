#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Base Image Minimization ===${NC}"
echo ""

# Check function
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

# Check function for exact match
check_exact() {
    local description="$1"
    local command="$2"
    local hint="$3"

    echo -n "Checking: $description... "

    if eval "$command" 2>/dev/null; then
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
    "Namespace lab-5-5 exists" \
    "kubectl get namespace lab-5-5" \
    "lab-5-5" \
    "Run ./setup.sh to create the namespace"

check \
    "Deployment distroless-app exists" \
    "kubectl get deployment distroless-app -n lab-5-5" \
    "distroless-app" \
    "Create the distroless-app deployment with gcr.io/distroless/static-debian12:nonroot image"

check \
    "distroless-app uses distroless image" \
    "kubectl get deployment distroless-app -n lab-5-5 -o jsonpath='{.spec.template.spec.containers[0].image}'" \
    "distroless" \
    "Use gcr.io/distroless/static-debian12:nonroot as the container image"

check \
    "distroless-app has runAsNonRoot: true" \
    "kubectl get deployment distroless-app -n lab-5-5 -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'" \
    "true" \
    "Set securityContext.runAsNonRoot: true in the pod spec"

check \
    "distroless-app has readOnlyRootFilesystem: true" \
    "kubectl get deployment distroless-app -n lab-5-5 -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}'" \
    "true" \
    "Set securityContext.readOnlyRootFilesystem: true in the container spec"

check \
    "distroless-app drops ALL capabilities" \
    "kubectl get deployment distroless-app -n lab-5-5 -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop}'" \
    "ALL" \
    "Set securityContext.capabilities.drop: [ALL] in the container spec"

check \
    "distroless-app has allowPrivilegeEscalation: false" \
    "kubectl get deployment distroless-app -n lab-5-5 -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}'" \
    "false" \
    "Set securityContext.allowPrivilegeEscalation: false in the container spec"

check \
    "ConfigMap multistage-dockerfile exists" \
    "kubectl get configmap multistage-dockerfile -n lab-5-5" \
    "multistage-dockerfile" \
    "Create a ConfigMap named 'multistage-dockerfile' with a multi-stage Dockerfile"

check \
    "multistage-dockerfile contains multi-stage build" \
    "kubectl get configmap multistage-dockerfile -n lab-5-5 -o jsonpath='{.data.Dockerfile}'" \
    "FROM" \
    "The Dockerfile should contain at least one FROM statement for multi-stage build"

check \
    "Pod minimal-alpine-pod exists" \
    "kubectl get pod minimal-alpine-pod -n lab-5-5" \
    "minimal-alpine-pod" \
    "Create a pod named 'minimal-alpine-pod' using alpine:3.19"

check \
    "minimal-alpine-pod uses Alpine image" \
    "kubectl get pod minimal-alpine-pod -n lab-5-5 -o jsonpath='{.spec.containers[0].image}'" \
    "alpine" \
    "Use alpine:3.19 as the container image for minimal-alpine-pod"

check \
    "minimal-alpine-pod has readOnlyRootFilesystem" \
    "kubectl get pod minimal-alpine-pod -n lab-5-5 -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'" \
    "true" \
    "Set readOnlyRootFilesystem: true in the container security context"

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
