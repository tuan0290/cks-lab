#!/bin/bash
# Lab 1.3 – Ingress TLS
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 1.3 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Ingress Controller đang chạy ---

echo "Kiểm tra tiêu chí 1: NGINX Ingress Controller đang chạy"

INGRESS_RUNNING=$(kubectl get pods -n ingress-nginx \
  -l app.kubernetes.io/component=controller \
  --no-headers 2>/dev/null | grep -c "Running" || true)

if [ "$INGRESS_RUNNING" -gt 0 ]; then
  pass "NGINX Ingress Controller đang chạy ($INGRESS_RUNNING pod Running)"
else
  fail "NGINX Ingress Controller không tìm thấy hoặc không Running" \
       "Cài đặt: helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace"
fi

echo ""

# --- Tiêu chí 2: IngressClass nginx tồn tại ---

echo "Kiểm tra tiêu chí 2: IngressClass 'nginx' tồn tại"

if kubectl get ingressclass nginx &>/dev/null 2>&1; then
  CONTROLLER=$(kubectl get ingressclass nginx -o jsonpath='{.spec.controller}' 2>/dev/null)
  pass "IngressClass 'nginx' tồn tại (controller: ${CONTROLLER})"
else
  # Kiểm tra bất kỳ IngressClass nào
  ANY_CLASS=$(kubectl get ingressclass --no-headers 2>/dev/null | head -1 | awk '{print $1}')
  if [ -n "$ANY_CLASS" ]; then
    fail "IngressClass 'nginx' không tìm thấy, nhưng có IngressClass '${ANY_CLASS}'" \
         "Dùng ingressClassName: ${ANY_CLASS} trong Ingress resource"
  else
    fail "Không có IngressClass nào trong cluster" \
         "Cài Ingress Controller để tạo IngressClass tự động"
  fi
fi

echo ""

# --- Tiêu chí 3: TLS Secret tồn tại ---

echo "Kiểm tra tiêu chí 3: Secret 'tls-secret' tồn tại với type kubernetes.io/tls"

SECRET_TYPE=$(kubectl get secret tls-secret -n tls-lab \
  -o jsonpath='{.type}' 2>/dev/null)

if [ "$SECRET_TYPE" = "kubernetes.io/tls" ]; then
  pass "Secret 'tls-secret' tồn tại với type 'kubernetes.io/tls'"
elif [ -z "$SECRET_TYPE" ]; then
  fail "Secret 'tls-secret' không tìm thấy trong namespace 'tls-lab'" \
       "kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key -n tls-lab"
else
  fail "Secret 'tls-secret' có type sai: '${SECRET_TYPE}'" \
       "Xóa và tạo lại: kubectl delete secret tls-secret -n tls-lab"
fi

echo ""

# --- Tiêu chí 4: Ingress tồn tại với ingressClassName và TLS ---

echo "Kiểm tra tiêu chí 4: Ingress 'tls-ingress' có ingressClassName và TLS"

if ! kubectl get ingress tls-ingress -n tls-lab &>/dev/null; then
  fail "Ingress 'tls-ingress' không tìm thấy trong namespace 'tls-lab'" \
       "Tạo Ingress theo Bước 6 trong README.md"
else
  INGRESS_CLASS=$(kubectl get ingress tls-ingress -n tls-lab \
    -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
  TLS_CONFIG=$(kubectl get ingress tls-ingress -n tls-lab \
    -o jsonpath='{.spec.tls}' 2>/dev/null)

  CLASS_OK=1
  TLS_OK=1

  if [ -z "$INGRESS_CLASS" ]; then
    fail "Ingress 'tls-ingress' thiếu 'ingressClassName'" \
         "Thêm spec.ingressClassName: nginx vào Ingress"
    CLASS_OK=0
  fi

  if [ -z "$TLS_CONFIG" ] || [ "$TLS_CONFIG" = "null" ] || [ "$TLS_CONFIG" = "[]" ]; then
    fail "Ingress 'tls-ingress' thiếu cấu hình TLS (spec.tls)" \
         "Thêm spec.tls với hosts và secretName vào Ingress"
    TLS_OK=0
  fi

  if [ "$CLASS_OK" -eq 1 ] && [ "$TLS_OK" -eq 1 ]; then
    pass "Ingress 'tls-ingress' có ingressClassName='${INGRESS_CLASS}' và cấu hình TLS"
  fi
fi

echo ""

# --- Tóm tắt ---

TOTAL=$((PASS + FAIL))
echo "=========================================="
echo " Kết quả: ${PASS}/${TOTAL} tiêu chí đạt"
echo "=========================================="

if [ "$FAILED" -eq 1 ]; then
  echo ""; echo "Một số tiêu chí chưa đạt. Xem gợi ý ở trên và thử lại."
  exit 1
else
  echo ""; echo "Chúc mừng! Bạn đã hoàn thành Lab 1.3."
  echo ""
  echo "Test HTTPS thực sự:"
  HTTPS_PORT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
    -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || echo "30443")
  NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
  echo "  curl -k -H 'Host: app.tls-lab.local' https://${NODE_IP}:${HTTPS_PORT}/"
  echo ""
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
