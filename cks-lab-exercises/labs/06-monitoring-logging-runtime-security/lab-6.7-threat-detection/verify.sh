#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Threat Detection - Attack Simulation and Response ===${NC}"
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
    "Namespace lab-6-7 exists" \
    "kubectl get namespace lab-6-7" \
    "lab-6-7" \
    "Run ./setup.sh to create the namespace"

check \
    "Attacker pod exists" \
    "kubectl get pod attacker-pod -n lab-6-7" \
    "attacker-pod" \
    "Run ./setup.sh to create the attacker simulation pod"

check \
    "Falco namespace exists" \
    "kubectl get namespace falco" \
    "falco" \
    "Create the falco namespace: kubectl create namespace falco"

check \
    "Falco threat detection ConfigMap exists" \
    "kubectl get configmap falco-threat-detection -n falco" \
    "falco-threat-detection" \
    "Create ConfigMap: kubectl create configmap falco-threat-detection --from-file=falco-threat-detection-rules.yaml -n falco"

check \
    "ConfigMap contains shell detection rule" \
    "kubectl get configmap falco-threat-detection -n falco -o yaml" \
    "Shell Spawned\|shell_procs\|spawned_process" \
    "Add a rule to detect shell spawning in containers"

check \
    "ConfigMap contains network detection rule" \
    "kubectl get configmap falco-threat-detection -n falco -o yaml" \
    "outbound\|Unexpected.*Connection\|network" \
    "Add a rule to detect unexpected outbound connections"

check \
    "ConfigMap contains container escape rule" \
    "kubectl get configmap falco-threat-detection -n falco -o yaml" \
    "escape\|/proc\|Container Escape" \
    "Add a rule to detect container escape attempts"

check \
    "Incident response NetworkPolicy exists (attacker isolated)" \
    "kubectl get networkpolicy isolate-attacker -n lab-6-7" \
    "isolate-attacker" \
    "Apply the isolation NetworkPolicy: kubectl apply -f isolate-attacker.yaml"

check \
    "Isolation policy blocks both Ingress and Egress" \
    "kubectl get networkpolicy isolate-attacker -n lab-6-7 -o yaml" \
    "Ingress" \
    "Include both Ingress and Egress in the isolation policy policyTypes"

check \
    "Isolation policy targets attacker role" \
    "kubectl get networkpolicy isolate-attacker -n lab-6-7 -o yaml" \
    "role: attacker\|attacker" \
    "Use podSelector with matchLabels role: attacker"

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
