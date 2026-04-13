#!/bin/bash
# Lab 6.2 – Audit Log Analysis
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 6.2 – Dọn dẹp môi trường"
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

# --- Xóa namespace audit-analysis-lab ---

echo "Xóa namespace audit-analysis-lab..."

if kubectl get namespace audit-analysis-lab &>/dev/null; then
  kubectl delete namespace audit-analysis-lab --ignore-not-found=true
  echo "[OK] Namespace 'audit-analysis-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'audit-analysis-lab' không tồn tại."
fi

# --- Xóa file tạm ---

for f in /tmp/sample-audit.log /tmp/answers.txt; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "[OK] File $f đã được xóa."
  else
    echo "[SKIP] File $f không tồn tại."
  fi
done

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
