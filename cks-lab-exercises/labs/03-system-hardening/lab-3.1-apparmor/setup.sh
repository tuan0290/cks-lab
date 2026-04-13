#!/bin/bash
# Lab 3.1 – AppArmor
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 3.1 – AppArmor"
echo " Đang khởi tạo môi trường..."
echo "=========================================="

# --- Kiểm tra prerequisites ---

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy. Vui lòng cài đặt kubectl trước."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến Kubernetes cluster."
  echo "        Kiểm tra kubeconfig: kubectl cluster-info"
  exit 1
fi

echo "[OK] kubectl và cluster kết nối thành công."

# --- Tạo namespace apparmor-lab ---

echo ""
echo "Tạo namespace apparmor-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: apparmor-lab
  labels:
    lab: "3.1"
    purpose: apparmor
EOF

echo "[OK] Namespace 'apparmor-lab' đã được tạo."

# --- Tạo AppArmor profile file tại /tmp/k8s-deny-write ---

echo ""
echo "Tạo AppArmor profile file tại /tmp/k8s-deny-write..."

cat > /tmp/k8s-deny-write <<'PROFILE'
#include <tunables/global>

profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  # Cho phép đọc mọi file
  file,

  # Chặn tất cả thao tác ghi và append file
  deny /** w,
  deny /** a,
}
PROFILE

echo "[OK] AppArmor profile đã được tạo tại /tmp/k8s-deny-write."

# --- Hướng dẫn load profile ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:     apparmor-lab"
echo "  Profile file:  /tmp/k8s-deny-write"
echo ""
echo "BƯỚC TIẾP THEO — Tải AppArmor profile lên node:"
echo ""
echo "  Bạn cần SSH vào node worker và chạy lệnh sau để load profile:"
echo ""
echo "    sudo apparmor_parser -r -W /tmp/k8s-deny-write"
echo ""
echo "  Nếu file /tmp/k8s-deny-write chưa có trên node, copy trước:"
echo ""
echo "    scp /tmp/k8s-deny-write <user>@<node-ip>:/tmp/k8s-deny-write"
echo "    ssh <user>@<node-ip> 'sudo apparmor_parser -r -W /tmp/k8s-deny-write'"
echo ""
echo "  Xác minh profile đã được load:"
echo "    sudo aa-status | grep k8s-deny-write"
echo ""
echo "Sau khi load profile, đọc README.md và thực hiện bài lab:"
echo "  1. Tạo pod secure-pod với AppArmor annotation"
echo "  2. Xác minh profile hoạt động"
echo "  3. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
