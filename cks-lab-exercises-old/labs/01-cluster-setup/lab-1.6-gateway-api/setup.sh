#!/bin/bash
# Lab 1.6 – Gateway API với TLS
# Script khởi tạo môi trường lab
# NOTE: Cài đặt Gateway Controller và tạo GatewayClass được hướng dẫn trong README.md
#       Script này chỉ tạo namespace và backend workload

set -e

echo "=========================================="
echo " Lab 1.6 – Gateway API với TLS"
echo " Đang khởi tạo môi trường..."
echo "=========================================="

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."; exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến cluster."; exit 1
fi

echo "[OK] kubectl và cluster kết nối thành công."

# Kiểm tra Gateway API CRDs
echo ""
echo "Kiểm tra Gateway API CRDs..."
if kubectl get crd gateways.gateway.networking.k8s.io &>/dev/null 2>&1; then
  echo "[OK] Gateway API CRDs đã được cài đặt."
else
  echo "[INFO] Gateway API CRDs chưa được cài đặt."
  echo "       Cài đặt theo Bước 1 trong README.md:"
  echo "       kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml"
fi

# Kiểm tra GatewayClass
echo ""
echo "Kiểm tra GatewayClass..."
GWCLASS=$(kubectl get gatewayclass --no-headers 2>/dev/null | head -3)
if [ -n "$GWCLASS" ]; then
  echo "[OK] GatewayClass có sẵn:"
  echo "$GWCLASS"
else
  echo "[INFO] Chưa có GatewayClass."
  echo "       Cài Gateway Controller theo Bước 2 trong README.md."
fi

# Tạo namespace gateway-lab
echo ""
echo "Tạo namespace gateway-lab..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: gateway-lab
  labels:
    lab: "1.6"
    purpose: gateway-api-tls
EOF
echo "[OK] Namespace 'gateway-lab' đã được tạo."

# Deploy nginx backend
echo ""
echo "Triển khai nginx backend trong gateway-lab..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: gateway-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: gateway-lab
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
echo "[OK] Deployment và Service 'nginx-service' đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:  gateway-lab"
echo "  Deployment: nginx-deployment"
echo "  Service:    nginx-service (port: 80)"
echo ""
echo "BƯỚC TIẾP THEO (theo thứ tự trong README.md):"
echo ""
echo "  Bước 1: Cài Gateway API CRDs"
echo "  Bước 2: Cài NGINX Gateway Fabric (Controller)"
echo "  Bước 3: Tạo GatewayClass (thường tự động sau khi cài Controller)"
echo "  Bước 4: Tạo TLS certificate và Secret"
echo "  Bước 5: Tạo Gateway với TLS listener"
echo "  Bước 6: Tạo HTTPRoute"
echo "  Bước 7: Test HTTPS"
echo ""
echo "Dọn dẹp: bash cleanup.sh"
echo ""
