#!/bin/bash
# Lab 5.3 – ImagePolicyWebhook Setup
# Script dọn dẹp môi trường lab

POLICY_DIR="/etc/kubernetes/policywebhook"
APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

echo "=========================================="
echo " Lab 5.3 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

# --- Xóa ImagePolicyWebhook khỏi kube-apiserver ---

if [ -f "$APISERVER_MANIFEST" ]; then
  echo "Xóa ImagePolicyWebhook khỏi kube-apiserver manifest..."

  # Backup trước khi sửa
  cp "$APISERVER_MANIFEST" "${APISERVER_MANIFEST}.bak-cleanup"

  # Xóa dòng enable-admission-plugins nếu chỉ có ImagePolicyWebhook
  # Hoặc giữ lại NodeRestriction nếu có cả hai
  if grep -q "ImagePolicyWebhook" "$APISERVER_MANIFEST"; then
    sed -i 's/,ImagePolicyWebhook//g' "$APISERVER_MANIFEST"
    sed -i 's/ImagePolicyWebhook,//g' "$APISERVER_MANIFEST"
    sed -i '/--enable-admission-plugins=ImagePolicyWebhook/d' "$APISERVER_MANIFEST"
    echo "[OK] Đã xóa ImagePolicyWebhook khỏi --enable-admission-plugins"
  else
    echo "[SKIP] ImagePolicyWebhook không có trong manifest."
  fi

  # Xóa --admission-control-config-file
  if grep -q "admission-control-config-file" "$APISERVER_MANIFEST"; then
    sed -i '/admission-control-config-file/d' "$APISERVER_MANIFEST"
    echo "[OK] Đã xóa --admission-control-config-file"
  else
    echo "[SKIP] --admission-control-config-file không có trong manifest."
  fi

  echo "     Backup lưu tại: ${APISERVER_MANIFEST}.bak-cleanup"
else
  echo "[SKIP] Không tìm thấy $APISERVER_MANIFEST"
fi

# --- Xóa thư mục policy ---

echo ""
if [ -d "$POLICY_DIR" ]; then
  echo "Xóa thư mục $POLICY_DIR..."
  rm -rf "$POLICY_DIR"
  echo "[OK] Thư mục $POLICY_DIR đã được xóa."
else
  echo "[SKIP] Thư mục $POLICY_DIR không tồn tại."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Lưu ý: kube-apiserver sẽ tự restart sau khi manifest thay đổi."
echo "Kiểm tra: watch crictl ps"
echo ""
