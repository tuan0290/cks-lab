#!/bin/bash
# Lab 3.2 – Seccomp
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 3.2 – Seccomp"
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

# --- Tạo namespace seccomp-lab ---

echo ""
echo "Tạo namespace seccomp-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: seccomp-lab
  labels:
    lab: "3.2"
    purpose: seccomp
EOF

echo "[OK] Namespace 'seccomp-lab' đã được tạo."

# --- Tạo Seccomp profile JSON tại /tmp/deny-write.json ---

echo ""
echo "Tạo Seccomp profile JSON tại /tmp/deny-write.json..."

cat > /tmp/deny-write.json <<'PROFILE'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": [
        "mkdir",
        "mkdirat",
        "chmod",
        "fchmod",
        "fchmodat",
        "chown",
        "fchown",
        "fchownat",
        "lchown"
      ],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
PROFILE

echo "[OK] Seccomp profile đã được tạo tại /tmp/deny-write.json."

# --- Hướng dẫn copy profile lên node ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:      seccomp-lab"
echo "  Profile file:   /tmp/deny-write.json"
echo ""
echo "BƯỚC TIẾP THEO — Copy Seccomp profile lên node worker:"
echo ""
echo "  Kubelet tìm kiếm Seccomp profile tại /var/lib/kubelet/seccomp/"
echo "  Bạn cần copy file vào đúng đường dẫn trên node worker:"
echo ""
echo "    # Tạo thư mục trên node (nếu chưa có)"
echo "    ssh <user>@<node-ip> 'sudo mkdir -p /var/lib/kubelet/seccomp/profiles'"
echo ""
echo "    # Copy profile lên node"
echo "    scp /tmp/deny-write.json <user>@<node-ip>:/tmp/deny-write.json"
echo "    ssh <user>@<node-ip> 'sudo cp /tmp/deny-write.json /var/lib/kubelet/seccomp/profiles/deny-write.json'"
echo ""
echo "    # Xác minh file đã được copy"
echo "    ssh <user>@<node-ip> 'ls -la /var/lib/kubelet/seccomp/profiles/'"
echo ""
echo "  Nếu đang dùng single-node cluster (ví dụ: kind, minikube):"
echo "    sudo mkdir -p /var/lib/kubelet/seccomp/profiles"
echo "    sudo cp /tmp/deny-write.json /var/lib/kubelet/seccomp/profiles/deny-write.json"
echo ""
echo "Sau khi copy profile, đọc README.md và thực hiện bài lab:"
echo "  1. Tạo pod hardened-pod với seccompProfile và SecurityContext đầy đủ"
echo "  2. Xác minh pod đang Running và seccomp profile hoạt động"
echo "  3. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
