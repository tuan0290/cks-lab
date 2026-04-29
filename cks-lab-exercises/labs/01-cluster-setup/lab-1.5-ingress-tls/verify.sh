#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${YELLOW}=== Lab Verification: Ingress TLS Configuration ===${NC}"
echo ""

check() {
    local description="$1"
    local result="$2"
    local hint="$3"
    echo -n "Checking: $description... "
    if [ "$result" = "pass" ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "  ${YELLOW}Hint: $hint${NC}"
        ((FAILED++))
    fi
}

# Check 1: Namespace exists
if kubectl get namespace lab-1-5 &>/dev/null; then
    check "Namespace lab-1-5 exists" "pass" ""
else
    check "Namespace lab-1-5 exists" "fail" "Run ./setup.sh first"
fi

# Check 2: TLS Secret exists with correct type
SECRET_TYPE=$(kubectl get secret app-tls-secret -n lab-1-5 -o jsonpath='{.type}' 2>/dev/null)
if [ "$SECRET_TYPE" = "kubernetes.io/tls" ]; then
    check "TLS Secret app-tls-secret exists with type kubernetes.io/tls" "pass" ""
else
    check "TLS Secret app-tls-secret exists with type kubernetes.io/tls" "fail" "Create: kubectl create secret tls app-tls-secret --cert=tls.crt --key=tls.key -n lab-1-5"
fi

# Check 3: Deployment web-app exists
if kubectl get deployment web-app -n lab-1-5 &>/dev/null; then
    check "Deployment web-app exists" "pass" ""
else
    check "Deployment web-app exists" "fail" "Create the web-app Deployment in namespace lab-1-5"
fi

# Check 4: Service web-app-svc exists
if kubectl get service web-app-svc -n lab-1-5 &>/dev/null; then
    check "Service web-app-svc exists" "pass" ""
else
    check "Service web-app-svc exists" "fail" "Create the web-app-svc Service in namespace lab-1-5"
fi

# Check 5: Ingress exists with TLS configured
INGRESS_TLS=$(kubectl get ingress web-app-ingress -n lab-1-5 -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null)
if [ "$INGRESS_TLS" = "app-tls-secret" ]; then
    check "Ingress web-app-ingress has TLS configured with app-tls-secret" "pass" ""
else
    check "Ingress web-app-ingress has TLS configured with app-tls-secret" "fail" "Create Ingress with spec.tls[0].secretName: app-tls-secret"
fi

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
