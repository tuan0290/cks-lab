#!/bin/bash
# Lab 1.6 – Gateway API Cleanup

echo "=========================================="
echo " Lab 1.6 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."; exit 1
fi

# Xóa HTTPRoute và Gateway
kubectl delete httproute app-route -n gateway-lab --ignore-not-found=true && \
  echo "[OK] HTTPRoute 'app-route' đã xóa." || true

kubectl delete gateway main-gateway -n gateway-lab --ignore-not-found=true && \
  echo "[OK] Gateway 'main-gateway' đã xóa." || true

# Xóa namespace gateway-lab
if kubectl get namespace gateway-lab &>/dev/null; then
  kubectl delete namespace gateway-lab --ignore-not-found=true
  echo "[OK] Namespace 'gateway-lab' đã xóa."
fi

# Xóa file tạm
rm -rf /tmp/gateway-lab 2>/dev/null && echo "[OK] /tmp/gateway-lab đã xóa." || true

echo ""
echo "[INFO] GatewayClass và Gateway Controller KHÔNG bị xóa."
echo "       Để xóa hoàn toàn:"
echo "         kubectl delete gatewayclass nginx"
echo "         helm uninstall nginx-gateway -n nginx-gateway"
echo "         kubectl delete namespace nginx-gateway"
echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
