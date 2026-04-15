#!/bin/bash
# Lab 1.6 – Gateway API với TLS

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 1.6 – Kiểm tra kết quả"
echo "=========================================="
echo ""

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() {
  echo "[FAIL] $1"
  [ -n "$2" ] && echo "       Gợi ý: $2"
  FAIL=$((FAIL + 1)); FAILED=1
}

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."; exit 1
fi

# --- Tiêu chí 1: Gateway API CRDs đã cài ---

echo "Kiểm tra tiêu chí 1: Gateway API CRDs đã được cài đặt"

if kubectl get crd gateways.gateway.networking.k8s.io &>/dev/null 2>&1 && \
   kubectl get crd httproutes.gateway.networking.k8s.io &>/dev/null 2>&1; then
  pass "Gateway API CRDs đã được cài đặt (gateways, httproutes)"
else
  fail "Gateway API CRDs chưa được cài đặt" \
       "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml"
fi

echo ""

# --- Tiêu chí 2: GatewayClass tồn tại và Accepted ---

echo "Kiểm tra tiêu chí 2: GatewayClass 'nginx' tồn tại và ACCEPTED"

if kubectl get gatewayclass nginx &>/dev/null 2>&1; then
  ACCEPTED=$(kubectl get gatewayclass nginx \
    -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
  if [ "$ACCEPTED" = "True" ]; then
    pass "GatewayClass 'nginx' tồn tại và ACCEPTED=True"
  else
    fail "GatewayClass 'nginx' tồn tại nhưng ACCEPTED=${ACCEPTED:-Unknown}" \
         "Kiểm tra Gateway Controller đang chạy: kubectl get pods -n nginx-gateway"
  fi
else
  ANY_CLASS=$(kubectl get gatewayclass --no-headers 2>/dev/null | head -1 | awk '{print $1}')
  if [ -n "$ANY_CLASS" ]; then
    fail "GatewayClass 'nginx' không tìm thấy, nhưng có GatewayClass '${ANY_CLASS}'" \
         "Tạo GatewayClass 'nginx' theo Bước 3 trong README.md"
  else
    fail "Không có GatewayClass nào trong cluster" \
         "Cài Gateway Controller theo Bước 2 trong README.md"
  fi
fi

echo ""

# --- Tiêu chí 3: Gateway main-gateway tồn tại và Programmed ---

echo "Kiểm tra tiêu chí 3: Gateway 'main-gateway' trong gateway-lab có PROGRAMMED=True"

if kubectl get gateway main-gateway -n gateway-lab &>/dev/null 2>&1; then
  PROGRAMMED=$(kubectl get gateway main-gateway -n gateway-lab \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  if [ "$PROGRAMMED" = "True" ]; then
    ADDRESS=$(kubectl get gateway main-gateway -n gateway-lab \
      -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
    pass "Gateway 'main-gateway' PROGRAMMED=True (address: ${ADDRESS:-pending})"
  else
    fail "Gateway 'main-gateway' tồn tại nhưng PROGRAMMED=${PROGRAMMED:-Unknown}" \
         "kubectl describe gateway main-gateway -n gateway-lab để xem lý do"
  fi
else
  fail "Gateway 'main-gateway' không tìm thấy trong namespace 'gateway-lab'" \
       "Tạo Gateway theo Bước 5 trong README.md"
fi

echo ""

# --- Tiêu chí 4: HTTPRoute app-route tồn tại ---

echo "Kiểm tra tiêu chí 4: HTTPRoute 'app-route' tồn tại và tham chiếu main-gateway"

if kubectl get httproute app-route -n gateway-lab &>/dev/null 2>&1; then
  PARENT=$(kubectl get httproute app-route -n gateway-lab \
    -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null)
  if [ "$PARENT" = "main-gateway" ]; then
    pass "HTTPRoute 'app-route' tồn tại và tham chiếu 'main-gateway'"
  else
    fail "HTTPRoute 'app-route' tồn tại nhưng parentRefs.name='${PARENT}' (mong đợi: 'main-gateway')" \
         "Sửa spec.parentRefs[0].name: main-gateway"
  fi
else
  fail "HTTPRoute 'app-route' không tìm thấy trong namespace 'gateway-lab'" \
       "Tạo HTTPRoute theo Bước 6 trong README.md"
fi

echo ""

TOTAL=$((PASS + FAIL))
echo "=========================================="
echo " Kết quả: ${PASS}/${TOTAL} tiêu chí đạt"
echo "=========================================="

if [ "$FAILED" -eq 1 ]; then
  echo ""; echo "Một số tiêu chí chưa đạt. Xem gợi ý ở trên và thử lại."
  exit 1
else
  echo ""; echo "Chúc mừng! Bạn đã hoàn thành Lab 1.6."
  echo ""
  echo "Test HTTPS:"
  HTTPS_PORT=$(kubectl get svc -n nginx-gateway \
    -o jsonpath='{.items[0].spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || echo "31443")
  NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
  echo "  curl -k -H 'Host: app.gateway-lab.local' https://${NODE_IP}:${HTTPS_PORT}/"
  echo ""
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
