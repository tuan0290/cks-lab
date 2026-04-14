#!/bin/bash
# Lab 1.5 – Cleanup

echo "=========================================="
echo " Lab 1.5 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."; exit 1
fi

# Xóa CSR nếu còn
kubectl delete csr dev-user --ignore-not-found=true && echo "[OK] CSR 'dev-user' đã xóa." || true

# Xóa namespace dev-ns
if kubectl get namespace dev-ns &>/dev/null; then
  kubectl delete namespace dev-ns --ignore-not-found=true
  echo "[OK] Namespace 'dev-ns' đã xóa."
fi

# Xóa file tạm
if [ -d /tmp/user-cert-lab ]; then
  rm -rf /tmp/user-cert-lab
  echo "[OK] Thư mục /tmp/user-cert-lab đã xóa."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
