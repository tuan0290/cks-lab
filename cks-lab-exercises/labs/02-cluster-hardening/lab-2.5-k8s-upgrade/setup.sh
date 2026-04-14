#!/bin/bash
# Lab 2.5 – Kubernetes Cluster Upgrade
# Script khởi tạo môi trường lab

echo "=========================================="
echo " Lab 2.5 – Kubernetes Cluster Upgrade"
echo " Đang kiểm tra môi trường..."
echo "=========================================="

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến cluster."
  exit 1
fi

echo "[OK] kubectl và cluster kết nối thành công."
echo ""

# Hiển thị thông tin phiên bản hiện tại
echo "=== Thông tin phiên bản hiện tại ==="
echo ""
echo "Kubernetes version:"
kubectl version --short 2>/dev/null || kubectl version

echo ""
echo "Node versions:"
kubectl get nodes -o custom-columns='NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,STATUS:.status.conditions[-1].type'

echo ""
echo "kubeadm version:"
kubeadm version 2>/dev/null || echo "[WARN] kubeadm không tìm thấy trên máy này"

echo ""
echo "=== Kế hoạch upgrade ==="
echo ""
echo "Chạy lệnh sau trên control-plane node để xem phiên bản có thể upgrade:"
echo "  sudo kubeadm upgrade plan"
echo ""
echo "Quy trình upgrade:"
echo "  1. Upgrade kubeadm trên control-plane"
echo "  2. sudo kubeadm upgrade apply v1.X.Y"
echo "  3. Drain control-plane: kubectl drain <node> --ignore-daemonsets --delete-emptydir-data"
echo "  4. Upgrade kubelet + kubectl trên control-plane"
echo "  5. Uncordon: kubectl uncordon <node>"
echo "  6. Lặp lại bước 3-5 cho từng worker node (dùng: kubeadm upgrade node)"
echo ""
echo "Sau khi upgrade, chạy verify.sh để kiểm tra kết quả."
echo ""
