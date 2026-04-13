#!/bin/bash
# Lab 5.5 – KubeLinter Static Analysis
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 5.5 – KubeLinter Static Analysis"
echo " Đang khởi tạo môi trường..."
echo "=========================================="

# --- Kiểm tra prerequisites ---

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy. Vui lòng cài đặt kubectl trước."
  exit 1
fi

echo "[OK] kubectl đã được cài đặt."

# kube-linter không bắt buộc trong setup — học viên tự cài trong bài lab
if command -v kube-linter &>/dev/null; then
  echo "[OK] kube-linter đã được cài đặt: $(kube-linter version 2>/dev/null || echo 'unknown version')"
else
  echo "[INFO] kube-linter chưa được cài đặt."
  echo "       Bước 1 của bài lab sẽ hướng dẫn cài đặt."
fi

# --- Tạo thư mục lab ---

echo ""
echo "Tạo thư mục /tmp/kubelinter-lab/..."

mkdir -p /tmp/kubelinter-lab

echo "[OK] Thư mục /tmp/kubelinter-lab/ đã được tạo."

# --- Tạo insecure-deployment.yaml ---

echo ""
echo "Tạo /tmp/kubelinter-lab/insecure-deployment.yaml..."

cat > /tmp/kubelinter-lab/insecure-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insecure-app
  namespace: default
  labels:
    app: insecure-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: insecure-app
  template:
    metadata:
      labels:
        app: insecure-app
    spec:
      containers:
      - name: app
        # VẤN ĐỀ 1: image dùng tag latest (không xác định version cụ thể)
        image: nginx:latest
        # VẤN ĐỀ 2: không có securityContext — container chạy với UID 0 (root)
        # VẤN ĐỀ 3: không có resources.limits — có thể chiếm toàn bộ tài nguyên node
        securityContext:
          # VẤN ĐỀ 4: privileged: true — container có toàn quyền truy cập host kernel
          privileged: true
          # VẤN ĐỀ 5: runAsUser: 0 — chạy với UID 0 (root)
          runAsUser: 0
EOF

echo "[OK] File /tmp/kubelinter-lab/insecure-deployment.yaml đã được tạo."

# --- Tạo .kube-linter.yaml mẫu ---

echo ""
echo "Tạo /tmp/kubelinter-lab/.kube-linter.yaml..."

cat > /tmp/kubelinter-lab/.kube-linter.yaml <<'EOF'
# .kube-linter.yaml – Cấu hình KubeLinter
# Tài liệu: https://docs.kubelinter.io/#/configuring-kubelinter

checks:
  # Dùng tất cả checks mặc định
  addAllBuiltIn: true

  # Tùy chọn: bỏ qua một số checks không phù hợp với môi trường của bạn
  # exclude:
  #   - "latest-tag"          # Bỏ qua check image tag latest
  #   - "no-extensions-v1beta1"  # Bỏ qua check API version cũ

  # Tùy chọn: chỉ chạy một số checks cụ thể
  # include:
  #   - "run-as-non-root"
  #   - "read-only-root-filesystem"
  #   - "no-read-only-root-fs"
  #   - "unset-cpu-requirements"
  #   - "unset-memory-requirements"

# Cấu hình custom checks (nâng cao)
# customChecks:
#   - name: "require-labels"
#     template: required-label
#     params:
#       key: "app.kubernetes.io/name"
EOF

echo "[OK] File /tmp/kubelinter-lab/.kube-linter.yaml đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  /tmp/kubelinter-lab/insecure-deployment.yaml  (manifest có 5 vấn đề bảo mật)"
echo "  /tmp/kubelinter-lab/.kube-linter.yaml          (cấu hình kube-linter mẫu)"
echo ""
echo "NHIỆM VỤ:"
echo ""
echo "  Bước 1: Cài đặt kube-linter"
echo "    curl -sSL https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz | tar xz"
echo "    sudo mv kube-linter /usr/local/bin/"
echo ""
echo "  Bước 2: Chạy lint trên manifest có vấn đề"
echo "    kube-linter lint /tmp/kubelinter-lab/insecure-deployment.yaml"
echo ""
echo "  Bước 3: Xác định các vấn đề được báo cáo"
echo ""
echo "  Bước 4: Tạo manifest đã sửa"
echo "    nano /tmp/kubelinter-lab/fixed-deployment.yaml"
echo ""
echo "  Bước 5: Verify"
echo "    kube-linter lint /tmp/kubelinter-lab/fixed-deployment.yaml"
echo "    bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
