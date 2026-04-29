#!/bin/bash
# Lab 2.1 – RBAC Least Privilege
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 2.1 – Dọn dẹp môi trường"
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

# --- Xóa ClusterRoleBinding nếu còn tồn tại ---

echo "Xóa ClusterRoleBinding app-sa-binding (nếu còn tồn tại)..."

if kubectl get clusterrolebinding app-sa-binding &>/dev/null; then
  kubectl delete clusterrolebinding app-sa-binding --ignore-not-found=true
  echo "[OK] ClusterRoleBinding 'app-sa-binding' đã được xóa."
else
  echo "[SKIP] ClusterRoleBinding 'app-sa-binding' không tồn tại."
fi

# --- Xóa namespace rbac-lab (bao gồm tất cả tài nguyên bên trong) ---

echo ""
echo "Xóa namespace rbac-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace rbac-lab &>/dev/null; then
  kubectl delete namespace rbac-lab --ignore-not-found=true
  echo "[OK] Namespace 'rbac-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'rbac-lab' không tồn tại."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
