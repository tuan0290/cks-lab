#!/bin/bash
# Lab 1.1 – NetworkPolicy Default Deny
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 1.1 – NetworkPolicy Default Deny"
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

# --- Tạo namespaces ---

echo ""
echo "Tạo namespaces..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: lab-network
  labels:
    lab: "1.1"
    purpose: network-policy-lab
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: frontend-ns
  labels:
    lab: "1.1"
    role: frontend
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: backend-ns
  labels:
    lab: "1.1"
    role: backend
EOF

echo "[OK] Namespaces đã được tạo: lab-network, frontend-ns, backend-ns"

# --- Deploy nginx pod trong backend-ns ---

echo ""
echo "Triển khai backend pod (nginx) trong backend-ns..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: backend-pod
  namespace: backend-ns
  labels:
    app: backend
    lab: "1.1"
spec:
  containers:
  - name: nginx
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
EOF

echo "[OK] backend-pod đã được tạo trong backend-ns."

# --- Deploy curl pod trong frontend-ns ---

echo ""
echo "Triển khai frontend pod (curl) trong frontend-ns..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod
  namespace: frontend-ns
  labels:
    app: frontend
    lab: "1.1"
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.5.0
    command: ["sleep", "3600"]
EOF

echo "[OK] frontend-pod đã được tạo trong frontend-ns."

# --- Deploy curl pod trong default namespace (để kiểm tra isolation) ---

echo ""
echo "Triển khai test pod trong default namespace..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: default-curl-pod
  namespace: default
  labels:
    app: test-client
    lab: "1.1"
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.5.0
    command: ["sleep", "3600"]
EOF

echo "[OK] default-curl-pod đã được tạo trong default namespace."

# --- Chờ pods sẵn sàng ---

echo ""
echo "Chờ các pod khởi động (tối đa 60 giây)..."

kubectl wait --for=condition=Ready pod/backend-pod -n backend-ns --timeout=60s 2>/dev/null \
  && echo "[OK] backend-pod sẵn sàng." \
  || echo "[WARN] backend-pod chưa sẵn sàng — tiếp tục (có thể cần thêm thời gian)."

kubectl wait --for=condition=Ready pod/frontend-pod -n frontend-ns --timeout=60s 2>/dev/null \
  && echo "[OK] frontend-pod sẵn sàng." \
  || echo "[WARN] frontend-pod chưa sẵn sàng — tiếp tục."

kubectl wait --for=condition=Ready pod/default-curl-pod -n default --timeout=60s 2>/dev/null \
  && echo "[OK] default-curl-pod sẵn sàng." \
  || echo "[WARN] default-curl-pod chưa sẵn sàng — tiếp tục."

# --- Tóm tắt ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: lab-network, frontend-ns, backend-ns"
echo "  Pod:       backend-pod (backend-ns)"
echo "             frontend-pod (frontend-ns)"
echo "             default-curl-pod (default)"
echo ""
echo "Bước tiếp theo:"
echo "  1. Đọc README.md để hiểu yêu cầu bài lab"
echo "  2. Tạo NetworkPolicy theo hướng dẫn"
echo "  3. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
