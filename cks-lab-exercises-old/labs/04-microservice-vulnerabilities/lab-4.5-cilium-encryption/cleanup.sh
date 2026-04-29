#!/bin/bash
# Lab 4.5 – Pod-to-Pod Encryption với Cilium
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 4.5 – Dọn dẹp môi trường"
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

# --- Xóa namespace cilium-lab ---

echo "Xóa namespace cilium-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace cilium-lab &>/dev/null; then
  kubectl delete namespace cilium-lab --ignore-not-found=true
  echo "[OK] Namespace 'cilium-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'cilium-lab' không tồn tại."
fi

echo ""
echo "Lưu ý:"
echo "  Cấu hình WireGuard encryption trên Cilium KHÔNG bị xóa bởi script này."
echo "  Đây là cấu hình cluster-wide và nên được giữ lại."
echo ""
echo "  Nếu muốn tắt WireGuard encryption (không khuyến nghị):"
echo "  kubectl patch configmap cilium-config -n kube-system \\"
echo "    --type merge -p '{\"data\":{\"enable-wireguard\":\"false\"}}'"
echo "  kubectl rollout restart daemonset/cilium -n kube-system"
echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
