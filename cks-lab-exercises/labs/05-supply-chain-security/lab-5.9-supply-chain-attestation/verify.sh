#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Supply Chain Attestation ===${NC}"
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
    "Namespace lab-5-9 exists" \
    "kubectl get namespace lab-5-9" \
    "lab-5-9" \
    "Run ./setup.sh to create the namespace"

check \
    "ConfigMap slsa-policy-config exists" \
    "kubectl get configmap slsa-policy-config -n lab-5-9" \
    "slsa-policy-config" \
    "Create a ConfigMap named 'slsa-policy-config' with SLSA settings"

check \
    "slsa-policy-config has slsa-level" \
    "kubectl get configmap slsa-policy-config -n lab-5-9 -o jsonpath='{.data.slsa-level}'" \
    "2" \
    "Set slsa-level: '2' in the slsa-policy-config ConfigMap"

check \
    "ConfigMap intoto-attestation-example exists" \
    "kubectl get configmap intoto-attestation-example -n lab-5-9" \
    "intoto-attestation-example" \
    "Create a ConfigMap named 'intoto-attestation-example' with attestation JSON"

check \
    "intoto-attestation-example contains in-toto statement" \
    "kubectl get configmap intoto-attestation-example -n lab-5-9 -o jsonpath='{.data.attestation\\.json}'" \
    "in-toto.io" \
    "The attestation JSON should contain the in-toto statement type"

check \
    "ClusterPolicy verify-slsa-attestation exists" \
    "kubectl get clusterpolicy verify-slsa-attestation" \
    "verify-slsa-attestation" \
    "Create a ClusterPolicy named 'verify-slsa-attestation'"

check \
    "verify-slsa-attestation has verifyImages rule" \
    "kubectl get clusterpolicy verify-slsa-attestation -o jsonpath='{.spec.rules[0].verifyImages}'" \
    "imageReferences" \
    "The policy should have a verifyImages section"

check \
    "verify-slsa-attestation checks attestations" \
    "kubectl get clusterpolicy verify-slsa-attestation -o jsonpath='{.spec.rules[0].verifyImages[0].attestations}'" \
    "predicateType" \
    "The verifyImages rule should include attestations with predicateType"

check \
    "Deployment attested-app exists" \
    "kubectl get deployment attested-app -n lab-5-9" \
    "attested-app" \
    "Create a Deployment named 'attested-app'"

check \
    "attested-app has SLSA annotation" \
    "kubectl get deployment attested-app -n lab-5-9 -o jsonpath='{.metadata.annotations}'" \
    "slsa" \
    "Add security.slsa/level annotation to the deployment"

check \
    "attested-app has provenance annotation" \
    "kubectl get deployment attested-app -n lab-5-9 -o jsonpath='{.metadata.annotations}'" \
    "provenance" \
    "Add security.slsa/provenance-verified annotation to the deployment"

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
