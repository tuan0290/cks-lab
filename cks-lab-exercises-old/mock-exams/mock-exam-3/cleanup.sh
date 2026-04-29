#!/bin/bash
# Mock Exam 3 – Cleanup Script

set -e

echo "=========================================="
echo " Mock Exam 3 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

if ! command -v kubectl &>/dev/null || ! kubectl cluster-info &>/dev/null 2>&1; then
  echo "[WARN] kubectl không kết nối được — bỏ qua bước xóa K8s resources."
else
  # Xóa namespaces (xóa tất cả resources bên trong)
  for NS in m3-app m3-db m3-secure m3-system m3-vuln m3-prod m3-runtime m3-audit; do
    if kubectl get namespace "$NS" &>/dev/null 2>&1; then
      kubectl delete namespace "$NS" --ignore-not-found=true
      echo "[OK] Namespace '$NS' đã được xóa."
    else
      echo "[SKIP] Namespace '$NS' không tồn tại."
    fi
  done
fi

# Xóa files tạm
for F in /tmp/m3-kubebench-output.txt /tmp/m3-scan.json /tmp/m3-critical-count.txt \
         /tmp/m3-deployment.yaml /tmp/m3-deployment-fixed.yaml /tmp/m3-config-issues.txt \
         /tmp/m3-audit.log /tmp/m3-audit-answers.txt /tmp/m3-threat-report.txt; do
  [ -f "$F" ] && rm -f "$F" && echo "[OK] Xóa $F" || true
done

# Xóa thư mục cosign
[ -d "/tmp/m3-cosign" ] && rm -rf /tmp/m3-cosign && echo "[OK] Xóa /tmp/m3-cosign" || true

# Xóa audit policy
[ -f "/etc/kubernetes/audit/policy.yaml" ] && \
  rm -f /etc/kubernetes/audit/policy.yaml && \
  echo "[OK] Xóa /etc/kubernetes/audit/policy.yaml" || true

# Xóa encryption config
[ -f "/etc/kubernetes/encryption/config.yaml" ] && \
  rm -f /etc/kubernetes/encryption/config.yaml && \
  echo "[OK] Xóa /etc/kubernetes/encryption/config.yaml" || true

# Xóa seccomp profile
[ -f "/var/lib/kubelet/seccomp/m3-profile.json" ] && \
  rm -f /var/lib/kubelet/seccomp/m3-profile.json && \
  echo "[OK] Xóa /var/lib/kubelet/seccomp/m3-profile.json" || true

# Xóa Falco rules
[ -f "/etc/falco/rules.d/m3-rules.yaml" ] && \
  rm -f /etc/falco/rules.d/m3-rules.yaml && \
  echo "[OK] Xóa /etc/falco/rules.d/m3-rules.yaml" || true

# Xóa ImagePolicyWebhook config (nếu đã tạo bởi exam này)
[ -d "/etc/kubernetes/policywebhook" ] && \
  rm -rf /etc/kubernetes/policywebhook && \
  echo "[OK] Xóa /etc/kubernetes/policywebhook" || true

# Revert kube-apiserver nếu đã sửa
APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
if [ -f "$APISERVER_MANIFEST" ]; then
  if grep -q "ImagePolicyWebhook\|m3\|audit/policy\|encryption/config" "$APISERVER_MANIFEST" 2>/dev/null; then
    cp "$APISERVER_MANIFEST" "${APISERVER_MANIFEST}.bak-m3-cleanup"
    sed -i '/ImagePolicyWebhook/d' "$APISERVER_MANIFEST"
    sed -i '/admission-control-config-file.*policywebhook/d' "$APISERVER_MANIFEST"
    sed -i '/audit-log-path.*audit\/audit/d' "$APISERVER_MANIFEST"
    sed -i '/audit-policy-file.*audit\/policy/d' "$APISERVER_MANIFEST"
    sed -i '/audit-log-maxage=7/d' "$APISERVER_MANIFEST"
    sed -i '/audit-log-maxbackup=3/d' "$APISERVER_MANIFEST"
    sed -i '/audit-log-maxsize=50/d' "$APISERVER_MANIFEST"
    sed -i '/encryption-provider-config.*encryption\/config/d' "$APISERVER_MANIFEST"
    echo "[OK] Đã revert kube-apiserver manifest (backup: ${APISERVER_MANIFEST}.bak-m3-cleanup)"
  fi
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
