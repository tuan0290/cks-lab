#!/bin/bash
# Lab 4.3 – Secret Volume Mount
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 4.3 – Secret Volume Mount"
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

# --- Tạo namespace secret-lab ---

echo ""
echo "Tạo namespace secret-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: secret-lab
  labels:
    lab: "4.3"
    purpose: secret-volume-mount
EOF

echo "[OK] Namespace 'secret-lab' đã được tạo."

# --- Tạo Secret app-credentials ---

echo ""
echo "Tạo Secret 'app-credentials' trong namespace secret-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-credentials
  namespace: secret-lab
  labels:
    lab: "4.3"
type: Opaque
stringData:
  username: dbadmin
  password: S3cr3tP@ssw0rd!
  api-key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
EOF

echo "[OK] Secret 'app-credentials' đã được tạo."

# --- Tạo pod insecure-app dùng Secret qua env var (cách sai) ---

echo ""
echo "Tạo pod 'insecure-app' sử dụng Secret qua environment variable (cách không an toàn)..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: insecure-app
  namespace: secret-lab
  labels:
    app: insecure-app
    lab: "4.3"
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: app-credentials
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-credentials
          key: password
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: app-credentials
          key: api-key
EOF

echo "[OK] Pod 'insecure-app' đã được tạo (dùng env var — cách không an toàn)."

# --- Chờ pod sẵn sàng ---

echo ""
echo "Chờ pod 'insecure-app' khởi động..."
kubectl wait --for=condition=Ready pod/insecure-app -n secret-lab --timeout=60s 2>/dev/null || \
  echo "[WARN] Pod chưa Ready sau 60s. Kiểm tra: kubectl get pod insecure-app -n secret-lab"

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: secret-lab"
echo "  Secret:    app-credentials (username, password, api-key)"
echo "  Pod:       insecure-app (dùng Secret qua env var — KHÔNG AN TOÀN)"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Xem pod insecure-app để hiểu vấn đề:"
echo "       kubectl describe pod insecure-app -n secret-lab"
echo ""
echo "  2. Tạo pod 'secure-app' mount Secret dưới dạng volume với defaultMode: 0400"
echo ""
echo "  3. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Xem README.md để biết hướng dẫn chi tiết."
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
