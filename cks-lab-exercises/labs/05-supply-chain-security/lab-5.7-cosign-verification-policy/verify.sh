#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Cosign Verification with Kyverno verifyImages ===${NC}"
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
    "Namespace lab-5-7 exists" \
    "kubectl get namespace lab-5-7" \
    "lab-5-7" \
    "Run ./setup.sh to create the namespace"

check \
    "ConfigMap cosign-public-key exists" \
    "kubectl get configmap cosign-public-key -n lab-5-7" \
    "cosign-public-key" \
    "Run: cosign generate-key-pair && kubectl create configmap cosign-public-key --from-file=cosign.pub=./cosign.pub -n lab-5-7"

check \
    "cosign-public-key contains a public key" \
    "kubectl get configmap cosign-public-key -n lab-5-7 -o jsonpath='{.data}'" \
    "cosign.pub" \
    "The ConfigMap should have a 'cosign.pub' key with the public key content"

check \
    "ClusterPolicy verify-image-signatures exists" \
    "kubectl get clusterpolicy verify-image-signatures" \
    "verify-image-signatures" \
    "Create a ClusterPolicy named 'verify-image-signatures' with verifyImages rule"

check \
    "verify-image-signatures has verifyImages rule" \
    "kubectl get clusterpolicy verify-image-signatures -o jsonpath='{.spec.rules[0].verifyImages}'" \
    "imageReferences" \
    "The policy should have a verifyImages section with imageReferences"

check \
    "ClusterPolicy audit-image-signatures exists" \
    "kubectl get clusterpolicy audit-image-signatures" \
    "audit-image-signatures" \
    "Create a ClusterPolicy named 'audit-image-signatures' in Audit mode"

check \
    "audit-image-signatures is in Audit mode" \
    "kubectl get clusterpolicy audit-image-signatures -o jsonpath='{.spec.validationFailureAction}'" \
    "Audit" \
    "Set validationFailureAction: Audit in the audit-image-signatures policy"

check \
    "Deployment verified-app exists" \
    "kubectl get deployment verified-app -n lab-5-7" \
    "verified-app" \
    "Create a Deployment named 'verified-app'"

check \
    "verified-app has cosign annotation" \
    "kubectl get deployment verified-app -n lab-5-7 -o jsonpath='{.metadata.annotations}'" \
    "cosign" \
    "Add security.cosign/verified annotation to the deployment"

check \
    "verified-app has security context" \
    "kubectl get deployment verified-app -n lab-5-7 -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'" \
    "true" \
    "Set runAsNonRoot: true in the pod security context"

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
