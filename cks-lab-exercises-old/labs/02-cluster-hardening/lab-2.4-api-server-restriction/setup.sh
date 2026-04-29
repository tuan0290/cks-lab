#!/bin/bash
# Lab 2.4 – Restrict API Server Access
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 2.4 – Restrict API Server Access"
echo " Đang kiểm tra môi trường..."
echo "=========================================="
echo ""

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

# --- Kiểm tra quyền truy cập kube-system ---

if kubectl get pods -n kube-system &>/dev/null; then
  echo "[OK] Có quyền truy cập namespace kube-system."
else
  echo "[WARN] Không thể truy cập namespace kube-system."
fi

# --- Hiển thị cấu hình hiện tại của kube-apiserver ---

echo ""
echo "Cấu hình hiện tại của kube-apiserver:"
echo "--------------------------------------"

APISERVER_POD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o name 2>/dev/null | head -1)

if [ -n "$APISERVER_POD" ]; then
  echo "Pod: $APISERVER_POD"
  echo ""
  echo "Các flag liên quan đến bài lab:"
  kubectl get "$APISERVER_POD" -n kube-system \
    -o jsonpath='{.spec.containers[0].command}' 2>/dev/null | tr ',' '\n' | \
    grep -E "anonymous-auth|admission-plugins|authorization-mode" || \
    echo "  (Không tìm thấy các flag này — cần kiểm tra và thêm)"
else
  echo "[WARN] Không tìm thấy kube-apiserver pod."
  echo "       Đảm bảo đang chạy trên hoặc có quyền truy cập control-plane node."
fi

# --- Kiểm tra manifest file ---

APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
echo ""
if [ -f "$APISERVER_MANIFEST" ]; then
  echo "[OK] Tìm thấy kube-apiserver manifest: $APISERVER_MANIFEST"
  echo ""
  echo "Nội dung liên quan:"
  grep -E "anonymous-auth|admission-plugins|authorization-mode" "$APISERVER_MANIFEST" 2>/dev/null || \
    echo "  (Không tìm thấy các flag này trong manifest)"
else
  echo "[INFO] Không tìm thấy $APISERVER_MANIFEST trên máy này."
  echo "       Nếu đây là worker node, hãy SSH vào control-plane node."
fi

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Bước tiếp theo:"
echo "  1. Đọc README.md để hiểu yêu cầu bài lab"
echo "  2. Sửa /etc/kubernetes/manifests/kube-apiserver.yaml"
echo "     Thêm: --anonymous-auth=false"
echo "     Thêm: --enable-admission-plugins=NodeRestriction (hoặc thêm vào danh sách)"
echo "     Xác nhận: --authorization-mode=Node,RBAC"
echo "  3. Ghi kết quả vào /tmp/api-server-check.txt"
echo "  4. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
