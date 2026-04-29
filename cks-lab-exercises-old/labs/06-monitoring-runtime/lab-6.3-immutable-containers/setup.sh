#!/bin/bash
# Lab 6.3 – Immutable Containers
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 6.3 – Immutable Containers"
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

# --- Tạo namespace immutable-lab ---

echo ""
echo "Tạo namespace immutable-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: immutable-lab
  labels:
    lab: "6.3"
    purpose: immutable-containers
EOF

echo "[OK] Namespace 'immutable-lab' đã được tạo."

# --- Tạo pod mutable-app (không có readOnlyRootFilesystem) ---

echo ""
echo "Tạo pod 'mutable-app' (không có readOnlyRootFilesystem)..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mutable-app
  namespace: immutable-lab
  labels:
    app: mutable-app
    lab: "6.3"
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
EOF

echo "[OK] Pod 'mutable-app' đã được tạo (không có readOnlyRootFilesystem)."

# Chờ pod sẵn sàng
echo "Chờ pod 'mutable-app' khởi động..."
kubectl wait --for=condition=Ready pod/mutable-app -n immutable-lab --timeout=60s 2>/dev/null || \
  echo "[WARN] Pod chưa Ready sau 60s. Kiểm tra: kubectl get pod mutable-app -n immutable-lab"

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: immutable-lab"
echo "  Pod:       mutable-app (nginx:1.25-alpine, không có readOnlyRootFilesystem)"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Xem cấu hình pod mutable-app:"
echo "       kubectl get pod mutable-app -n immutable-lab -o yaml"
echo ""
echo "  2. Thử ghi vào filesystem của mutable-app (sẽ thành công):"
echo "       kubectl exec mutable-app -n immutable-lab -- sh -c \"echo test > /etc/test.txt\""
echo ""
echo "  3. Tạo pod 'immutable-app' với readOnlyRootFilesystem: true"
echo "     và emptyDir mounts cho /tmp và /var/run:"
echo "       kubectl apply -f - <<EOF"
echo "       apiVersion: v1"
echo "       kind: Pod"
echo "       metadata:"
echo "         name: immutable-app"
echo "         namespace: immutable-lab"
echo "       spec:"
echo "         containers:"
echo "         - name: app"
echo "           image: nginx:1.25-alpine"
echo "           securityContext:"
echo "             readOnlyRootFilesystem: true"
echo "           volumeMounts:"
echo "           - name: tmp-dir"
echo "             mountPath: /tmp"
echo "           - name: run-dir"
echo "             mountPath: /var/run"
echo "         volumes:"
echo "         - name: tmp-dir"
echo "           emptyDir: {}"
echo "         - name: run-dir"
echo "           emptyDir: {}"
echo "       EOF"
echo ""
echo "  4. Xác minh container không thể ghi vào filesystem gốc:"
echo "       kubectl exec immutable-app -n immutable-lab -- sh -c \"echo test > /etc/test.txt\""
echo "       # Mong đợi: Read-only file system error"
echo ""
echo "  5. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
