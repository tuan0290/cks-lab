#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Runtime Immutability ===${NC}"
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

check_fail() {
    local description="$1"
    local command="$2"
    local hint="$3"

    echo -n "Checking: $description... "

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${RED}✗ FAIL (command succeeded when it should have failed)${NC}"
        if [ -n "$hint" ]; then
            echo -e "  ${YELLOW}Hint: $hint${NC}"
        fi
        ((FAILED++))
    else
        echo -e "${GREEN}✓ PASS (write correctly blocked)${NC}"
        ((PASSED++))
    fi
}

# Verification checks

check \
    "Namespace lab-6-9 exists" \
    "kubectl get namespace lab-6-9" \
    "lab-6-9" \
    "Run ./setup.sh to create the namespace"

check \
    "Immutable pod exists" \
    "kubectl get pod immutable-pod -n lab-6-9" \
    "immutable-pod" \
    "Create the immutable-pod with readOnlyRootFilesystem: true (see README Step 2)"

check \
    "Immutable pod is running" \
    "kubectl get pod immutable-pod -n lab-6-9 -o jsonpath='{.status.phase}'" \
    "Running" \
    "Wait for the pod to start: kubectl wait --for=condition=Ready pod/immutable-pod -n lab-6-9"

check \
    "Pod has readOnlyRootFilesystem: true" \
    "kubectl get pod immutable-pod -n lab-6-9 -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'" \
    "true" \
    "Set securityContext.readOnlyRootFilesystem: true in the pod spec"

check \
    "Pod has /tmp volume mount" \
    "kubectl get pod immutable-pod -n lab-6-9 -o yaml" \
    "mountPath: /tmp" \
    "Add an emptyDir volume mounted at /tmp"

check \
    "Pod has emptyDir volume for /tmp" \
    "kubectl get pod immutable-pod -n lab-6-9 -o yaml" \
    "emptyDir" \
    "Use emptyDir as the volume type for writable directories"

check \
    "Pod has allowPrivilegeEscalation: false" \
    "kubectl get pod immutable-pod -n lab-6-9 -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}'" \
    "false" \
    "Set securityContext.allowPrivilegeEscalation: false"

check \
    "Immutable deployment exists" \
    "kubectl get deployment immutable-deployment -n lab-6-9" \
    "immutable-deployment" \
    "Create the immutable-deployment (see README Step 4)"

check \
    "Deployment pods have readOnlyRootFilesystem" \
    "kubectl get deployment immutable-deployment -n lab-6-9 -o yaml" \
    "readOnlyRootFilesystem: true" \
    "Set readOnlyRootFilesystem: true in the deployment pod template"

check \
    "Deployment drops ALL capabilities" \
    "kubectl get deployment immutable-deployment -n lab-6-9 -o yaml" \
    "drop" \
    "Add capabilities.drop: [ALL] to the container security context"

check \
    "Falco immutability rules ConfigMap exists" \
    "kubectl get configmap falco-immutability-rules -n falco" \
    "falco-immutability-rules" \
    "Create the Falco rules ConfigMap (see README Step 5)"

check \
    "Falco rules detect write attempts" \
    "kubectl get configmap falco-immutability-rules -n falco -o yaml" \
    "open_write\|Write.*filesystem\|immutab" \
    "Add a Falco rule that detects open_write events"

# Test actual write blocking
echo ""
echo -e "${YELLOW}--- Runtime Tests ---${NC}"

if kubectl get pod immutable-pod -n lab-6-9 &> /dev/null 2>&1; then
    check_fail \
        "Write to root filesystem is blocked" \
        "kubectl exec -n lab-6-9 immutable-pod -- touch /test-write-blocked" \
        "The readOnlyRootFilesystem should prevent writes to /"

    check \
        "Write to /tmp is allowed" \
        "kubectl exec -n lab-6-9 immutable-pod -- sh -c 'touch /tmp/test-write && echo success'" \
        "success" \
        "Mount an emptyDir volume at /tmp to allow temporary writes"
else
    echo -e "${YELLOW}Skipping runtime tests - immutable-pod not found${NC}"
fi

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
