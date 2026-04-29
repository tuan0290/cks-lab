#!/bin/bash
# Lab 4.1 – Trivy Image Scan
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 4.1 – Trivy Image Scan"
echo " Đang khởi tạo môi trường..."
echo "=========================================="

# --- Kiểm tra prerequisites ---

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy. Vui lòng cài đặt kubectl trước."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến Kubernetes cluster."
  echo "        Kiểm tra kubeconfig: kubectl cluster-info"
  exit 1
fi

echo "[OK] kubectl và cluster kết nối thành công."

if ! command -v trivy &>/dev/null; then
  echo "[WARN] trivy không tìm thấy. Đang tự động cài đặt..."
  echo ""
  
  # Tự động cài đặt trivy
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
  
  if ! command -v trivy &>/dev/null; then
    echo "[ERROR] Không thể cài đặt trivy tự động."
    echo "        Vui lòng cài đặt thủ công: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
    exit 1
  fi
  
  echo "[OK] trivy đã được cài đặt thành công."
else
  echo "[OK] trivy đã được cài đặt."
fi

# --- Tạo namespace trivy-lab ---

echo ""
echo "Tạo namespace trivy-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: trivy-lab
  labels:
    lab: "4.1"
    purpose: trivy-image-scan
EOF

echo "[OK] Namespace 'trivy-lab' đã được tạo."

# --- Deploy pod với nginx:1.14.0 (image có lỗ hổng) ---

echo ""
echo "Deploy pod 'web-app' với image nginx:1.14.0 (image có lỗ hổng CRITICAL)..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: web-app
  namespace: trivy-lab
  labels:
    app: web-app
    lab: "4.1"
spec:
  containers:
  - name: nginx
    image: nginx:1.14.0
    ports:
    - containerPort: 80
EOF

echo "[OK] Pod 'web-app' đã được tạo với image nginx:1.14.0."

# --- Chờ pod sẵn sàng ---

echo ""
echo "Chờ pod 'web-app' khởi động..."
kubectl wait --for=condition=Ready pod/web-app -n trivy-lab --timeout=60s 2>/dev/null || \
  echo "[WARN] Pod chưa Ready sau 60s. Kiểm tra: kubectl get pod web-app -n trivy-lab"

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: trivy-lab"
echo "  Pod:       web-app (image: nginx:1.14.0)"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Quét image nginx:1.14.0 bằng trivy:"
echo "       trivy image --severity CRITICAL nginx:1.14.0"
echo ""
echo "  2. Xác định các lỗ hổng CRITICAL"
echo ""
echo "  3. Thay thế pod bằng image nginx:1.25-alpine:"
echo "       kubectl delete pod web-app -n trivy-lab"
echo "       kubectl run web-app --image=nginx:1.25-alpine --namespace=trivy-lab --restart=Never"
echo ""
echo "  4. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
