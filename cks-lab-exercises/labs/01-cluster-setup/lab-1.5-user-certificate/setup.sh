#!/bin/bash
# Lab 1.5 – Authentication với Certificate và ServiceAccount

set -e

echo "=========================================="
echo " Lab 1.5 – User Certificate & ServiceAccount"
echo " Đang khởi tạo môi trường..."
echo "=========================================="

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến cluster."
  exit 1
fi

if ! command -v openssl &>/dev/null; then
  echo "[ERROR] openssl không tìm thấy. Cài đặt: apt-get install openssl"
  exit 1
fi

echo "[OK] kubectl, cluster và openssl sẵn sàng."

# Tạo namespace dev-ns
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: dev-ns
  labels:
    lab: "1.5"
EOF
echo "[OK] Namespace 'dev-ns' đã được tạo."

# Tạo một số pod mẫu trong dev-ns để test
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sample-app
  namespace: dev-ns
  labels:
    app: sample
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
echo "[OK] Pod 'sample-app' đã được tạo trong dev-ns."

# Tạo thư mục làm việc
mkdir -p /tmp/user-cert-lab
echo "[OK] Thư mục /tmp/user-cert-lab đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: dev-ns"
echo "  Pod:       sample-app (dev-ns)"
echo "  Thư mục:   /tmp/user-cert-lab"
echo ""
echo "Bước tiếp theo:"
echo "  1. Đọc README.md để hiểu yêu cầu bài lab"
echo "  2. Tạo private key và CSR cho user dev-user"
echo "  3. Submit CSR lên Kubernetes và approve"
echo "  4. Tạo kubeconfig và test quyền"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
