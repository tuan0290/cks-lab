#!/bin/bash
# Lab 5.3 – Image Policy Webhook
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 5.3 – Dọn dẹp môi trường"
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

# --- Xóa Constraint ---

echo "Xóa Constraint 'allowed-repos'..."
kubectl delete k8sallowedrepos allowed-repos --ignore-not-found=true 2>/dev/null && \
  echo "[OK] Constraint 'allowed-repos' đã được xóa." || \
  echo "[SKIP] Constraint 'allowed-repos' không tồn tại hoặc CRD chưa được cài đặt."

# --- Xóa ConstraintTemplate ---

echo "Xóa ConstraintTemplate 'k8sallowedrepos'..."
kubectl delete constrainttemplate k8sallowedrepos --ignore-not-found=true 2>/dev/null && \
  echo "[OK] ConstraintTemplate 'k8sallowedrepos' đã được xóa." || \
  echo "[SKIP] ConstraintTemplate 'k8sallowedrepos' không tồn tại."

# --- Xóa namespace policy-lab ---

echo "Xóa namespace policy-lab..."

if kubectl get namespace policy-lab &>/dev/null; then
  kubectl delete namespace policy-lab --ignore-not-found=true
  echo "[OK] Namespace 'policy-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'policy-lab' không tồn tại."
fi

# --- Xóa file tạm ---

if [ -f /tmp/allowed-repos-template.yaml ]; then
  rm -f /tmp/allowed-repos-template.yaml
  echo "[OK] File /tmp/allowed-repos-template.yaml đã được xóa."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Lưu ý: OPA Gatekeeper vẫn còn trong cluster (nếu đã cài đặt)."
echo "Để xóa Gatekeeper hoàn toàn:"
echo "  kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml"
echo ""
