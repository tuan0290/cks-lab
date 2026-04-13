#!/bin/bash
# Lab 2.2 – Audit Policy
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 2.2 – Dọn dẹp môi trường"
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

# --- Xóa namespace audit-lab (bao gồm tất cả tài nguyên bên trong) ---

echo "Xóa namespace audit-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace audit-lab &>/dev/null; then
  kubectl delete namespace audit-lab --ignore-not-found=true
  echo "[OK] Namespace 'audit-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'audit-lab' không tồn tại."
fi

# --- Xóa audit policy template tại /tmp ---

echo ""
echo "Xóa audit policy template tại /tmp/audit-policy.yaml..."

if [ -f "/tmp/audit-policy.yaml" ]; then
  rm -f /tmp/audit-policy.yaml
  echo "[OK] /tmp/audit-policy.yaml đã được xóa."
else
  echo "[SKIP] /tmp/audit-policy.yaml không tồn tại."
fi

# --- Thông báo về cấu hình kube-apiserver ---

echo ""
echo "=========================================="
echo " Lưu ý về cấu hình kube-apiserver"
echo "=========================================="
echo ""
echo "Script này KHÔNG tự động hoàn tác các thay đổi trên kube-apiserver."
echo "Nếu bạn đã chỉnh sửa kube-apiserver manifest, hãy thực hiện thủ công:"
echo ""
echo "  1. Khôi phục từ backup:"
echo "     sudo cp /etc/kubernetes/kube-apiserver.yaml.bak \\"
echo "       /etc/kubernetes/manifests/kube-apiserver.yaml"
echo ""
echo "  2. Hoặc xóa các audit flags đã thêm:"
echo "     sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml"
echo "     # Xóa các dòng: --audit-policy-file, --audit-log-path,"
echo "     #               --audit-log-maxage, --audit-log-maxbackup, --audit-log-maxsize"
echo "     # Xóa volumeMounts và volumes liên quan đến audit"
echo ""
echo "  3. Xóa policy file trên control-plane node (nếu đã sao chép):"
echo "     sudo rm -rf /etc/kubernetes/audit/"
echo ""
echo "  4. Xóa audit log (tùy chọn):"
echo "     sudo rm -rf /var/log/kubernetes/audit/"
echo ""

echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu (trừ cấu hình kube-apiserver)."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
