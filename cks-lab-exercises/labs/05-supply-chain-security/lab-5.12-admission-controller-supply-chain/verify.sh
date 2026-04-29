#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Admission Controllers for Supply Chain Enforcement ===${NC}"
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
    "Namespace lab-5-12 exists" \
    "kubectl get namespace lab-5-12" \
    "lab-5-12" \
    "Run ./setup.sh to create the namespace"

check \
    "ConfigMap supply-chain-config exists" \
    "kubectl get configmap supply-chain-config -n lab-5-12" \
    "supply-chain-config" \
    "Create a ConfigMap named 'supply-chain-config'"

check \
    "supply-chain-config has approved-registries" \
    "kubectl get configmap supply-chain-config -n lab-5-12 -o jsonpath='{.data.approved-registries}'" \
    "gcr.io" \
    "Set approved-registries in the supply-chain-config ConfigMap"

check \
    "ClusterPolicy supply-chain-validate exists" \
    "kubectl get clusterpolicy supply-chain-validate" \
    "supply-chain-validate" \
    "Create a ClusterPolicy named 'supply-chain-validate'"

check \
    "supply-chain-validate has multiple rules" \
    "kubectl get clusterpolicy supply-chain-validate -o jsonpath='{.spec.rules}'" \
    "require-approved-registry" \
    "The policy should have a rule named 'require-approved-registry'"

check \
    "supply-chain-validate has non-root rule" \
    "kubectl get clusterpolicy supply-chain-validate -o jsonpath='{.spec.rules[*].name}'" \
    "require-non-root" \
    "Add a rule named 'require-non-root' to the supply-chain-validate policy"

check \
    "supply-chain-validate has resource limits rule" \
    "kubectl get clusterpolicy supply-chain-validate -o jsonpath='{.spec.rules[*].name}'" \
    "require-resource-limits" \
    "Add a rule named 'require-resource-limits' to the supply-chain-validate policy"

check \
    "ClusterPolicy supply-chain-mutate exists" \
    "kubectl get clusterpolicy supply-chain-mutate" \
    "supply-chain-mutate" \
    "Create a ClusterPolicy named 'supply-chain-mutate'"

check \
    "supply-chain-mutate has mutate rules" \
    "kubectl get clusterpolicy supply-chain-mutate -o jsonpath='{.spec.rules[0].mutate}'" \
    "patchStrategicMerge" \
    "The supply-chain-mutate policy should have mutate rules with patchStrategicMerge"

check \
    "Deployment compliant-app exists" \
    "kubectl get deployment compliant-app -n lab-5-12" \
    "compliant-app" \
    "Create a Deployment named 'compliant-app'"

check \
    "compliant-app has scan annotation" \
    "kubectl get deployment compliant-app -n lab-5-12 -o jsonpath='{.metadata.annotations}'" \
    "scan" \
    "Add security.scan/status annotation to the compliant-app deployment"

check \
    "compliant-app has supply-chain annotation" \
    "kubectl get deployment compliant-app -n lab-5-12 -o jsonpath='{.metadata.annotations}'" \
    "supply-chain" \
    "Add security.supply-chain/compliant annotation to the compliant-app deployment"

check \
    "compliant-app has runAsNonRoot: true" \
    "kubectl get deployment compliant-app -n lab-5-12 -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'" \
    "true" \
    "Set securityContext.runAsNonRoot: true in the pod spec"

check \
    "compliant-app has resource limits" \
    "kubectl get deployment compliant-app -n lab-5-12 -o jsonpath='{.spec.template.spec.containers[0].resources.limits}'" \
    "cpu" \
    "Set resource limits for CPU and memory in the container spec"

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
