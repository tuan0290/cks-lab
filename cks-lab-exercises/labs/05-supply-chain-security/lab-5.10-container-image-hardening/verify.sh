#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Container Image Hardening ===${NC}"
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
    "Namespace lab-5-10 exists" \
    "kubectl get namespace lab-5-10" \
    "lab-5-10" \
    "Run ./setup.sh to create the namespace"

check \
    "Namespace has PSS enforce label" \
    "kubectl get namespace lab-5-10 -o jsonpath='{.metadata.labels}'" \
    "pod-security.kubernetes.io/enforce" \
    "Add label: pod-security.kubernetes.io/enforce=restricted to the namespace"

check \
    "Namespace PSS enforce level is restricted" \
    "kubectl get namespace lab-5-10 -o jsonpath='{.metadata.labels.pod-security\\.kubernetes\\.io/enforce}'" \
    "restricted" \
    "Set pod-security.kubernetes.io/enforce=restricted on the namespace"

check \
    "ConfigMap hardening-checklist exists" \
    "kubectl get configmap hardening-checklist -n lab-5-10" \
    "hardening-checklist" \
    "Create a ConfigMap named 'hardening-checklist'"

check \
    "Deployment hardened-app exists" \
    "kubectl get deployment hardened-app -n lab-5-10" \
    "hardened-app" \
    "Create a Deployment named 'hardened-app'"

check \
    "hardened-app has runAsNonRoot: true" \
    "kubectl get deployment hardened-app -n lab-5-10 -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'" \
    "true" \
    "Set securityContext.runAsNonRoot: true in the pod spec"

check \
    "hardened-app has readOnlyRootFilesystem: true" \
    "kubectl get deployment hardened-app -n lab-5-10 -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}'" \
    "true" \
    "Set securityContext.readOnlyRootFilesystem: true in the container spec"

check \
    "hardened-app drops ALL capabilities" \
    "kubectl get deployment hardened-app -n lab-5-10 -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop}'" \
    "ALL" \
    "Set securityContext.capabilities.drop: [ALL] in the container spec"

check \
    "hardened-app has seccompProfile" \
    "kubectl get deployment hardened-app -n lab-5-10 -o jsonpath='{.spec.template.spec.securityContext.seccompProfile}'" \
    "RuntimeDefault" \
    "Set securityContext.seccompProfile.type: RuntimeDefault in the pod spec"

check \
    "hardened-app has allowPrivilegeEscalation: false" \
    "kubectl get deployment hardened-app -n lab-5-10 -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}'" \
    "false" \
    "Set securityContext.allowPrivilegeEscalation: false in the container spec"

check \
    "ClusterPolicy enforce-container-hardening exists" \
    "kubectl get clusterpolicy enforce-container-hardening" \
    "enforce-container-hardening" \
    "Create a ClusterPolicy named 'enforce-container-hardening'"

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
