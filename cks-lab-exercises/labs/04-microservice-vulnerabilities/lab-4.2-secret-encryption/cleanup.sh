#!/bin/bash
# Lab 4.2 – Secret Encryption at Rest
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 4.2 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến cluster."
  exit 1
fi

# --- Xóa namespace encryption-lab ---

echo "Xóa namespace encryption-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace encryption-lab &>/dev/null; then
  kubectl delete namespace encryption-lab --ignore-not-found=true
  echo "[OK] Namespace 'encryption-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'encryption-lab' không tồn tại."
fi

# --- Xóa file tạm ---

echo ""
echo "Xóa file tạm /tmp/encryption-config.yaml..."

if [ -f /tmp/encryption-config.yaml ]; then
  rm -f /tmp/encryption-config.yaml
  echo "[OK] File /tmp/encryption-config.yaml đã được xóa."
else
  echo "[SKIP] File /tmp/encryption-config.yaml không tồn tại."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo ""
echo "Lưu ý quan trọng: Nếu bạn đã cấu hình kube-apiserver với"
echo "--encryption-provider-config, hãy hoàn tác thủ công trên control-plane node:"
echo ""
echo "  1. Xóa flag --encryption-provider-config khỏi kube-apiserver manifest:"
echo "       sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml"
echo ""
echo "  2. Xóa volume mount và volume cho /etc/kubernetes/enc"
echo ""
echo "  3. Xóa thư mục cấu hình (tùy chọn):"
echo "       sudo rm -rf /etc/kubernetes/enc"
echo ""
echo "  4. Chờ kube-apiserver khởi động lại"
echo ""
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
