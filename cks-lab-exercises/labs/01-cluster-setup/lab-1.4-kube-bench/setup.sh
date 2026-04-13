#!/bin/bash
# Lab 1.4 – CIS Benchmark với kube-bench
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 1.4 – CIS Benchmark với kube-bench"
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

# --- Kiểm tra kube-bench ---

if command -v kube-bench &>/dev/null; then
  KUBE_BENCH_VERSION=$(kube-bench version 2>/dev/null || echo "unknown")
  echo "[OK] kube-bench đã được cài đặt: $KUBE_BENCH_VERSION"
else
  echo "[WARN] kube-bench chưa được cài đặt."
  echo ""
  echo "  Cài đặt kube-bench:"
  echo "  curl -L https://github.com/aquasecurity/kube-bench/releases/latest/download/kube-bench_linux_amd64.tar.gz | tar xz"
  echo "  sudo mv kube-bench /usr/local/bin/"
  echo ""
  echo "  Hoặc chạy qua Docker (không cần cài đặt):"
  echo "  docker run --rm --pid=host -v /etc:/etc:ro -v /var:/var:ro \\"
  echo "    -v \$(which kubectl):/usr/local/mount-from-host/bin/kubectl \\"
  echo "    -e KUBECONFIG=\$KUBECONFIG \\"
  echo "    aquasec/kube-bench:latest run --targets master"
  echo ""
fi

# --- Kiểm tra quyền truy cập kube-system ---

if kubectl get pods -n kube-system &>/dev/null; then
  echo "[OK] Có quyền truy cập namespace kube-system."
else
  echo "[WARN] Không thể truy cập namespace kube-system. Một số kiểm tra có thể thất bại."
fi

# --- Kiểm tra kube-apiserver manifest ---

APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
if [ -f "$APISERVER_MANIFEST" ]; then
  echo "[OK] Tìm thấy kube-apiserver manifest tại $APISERVER_MANIFEST"
  echo ""
  echo "Cấu hình hiện tại của kube-apiserver:"
  grep -E "profiling|anonymous-auth" "$APISERVER_MANIFEST" 2>/dev/null \
    && echo "" \
    || echo "  (Không tìm thấy flag profiling hoặc anonymous-auth — cần thêm)"
else
  echo "[INFO] Không tìm thấy $APISERVER_MANIFEST trên máy này."
  echo "       Nếu đây là control-plane node, hãy kiểm tra lại đường dẫn."
  echo "       Nếu đây là worker node, hãy SSH vào control-plane node để thực hiện bài lab."
fi

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Bước tiếp theo:"
echo "  1. Đọc README.md để hiểu yêu cầu bài lab"
echo "  2. Chạy kube-bench trên control-plane node:"
echo "     sudo kube-bench run --targets master"
echo "  3. Xác định các mục FAIL và sửa kube-apiserver manifest"
echo "  4. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Lưu ý: Bài lab này yêu cầu quyền sudo trên control-plane node"
echo "       để chỉnh sửa /etc/kubernetes/manifests/kube-apiserver.yaml"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
