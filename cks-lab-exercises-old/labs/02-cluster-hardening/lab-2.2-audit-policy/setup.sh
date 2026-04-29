#!/bin/bash
# Lab 2.2 – Audit Policy
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 2.2 – Audit Policy"
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

# --- Tạo namespace audit-lab ---

echo ""
echo "Tạo namespace audit-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: audit-lab
  labels:
    lab: "2.2"
    purpose: audit-policy
EOF

echo "[OK] Namespace 'audit-lab' đã được tạo."

# --- Tạo Secret mẫu trong audit-lab để kiểm tra ---

echo ""
echo "Tạo Secret mẫu trong audit-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: sample-secret
  namespace: audit-lab
  labels:
    lab: "2.2"
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQxMjM=
  api-key: c3VwZXItc2VjcmV0LWFwaS1rZXk=
EOF

echo "[OK] Secret 'sample-secret' đã được tạo trong namespace 'audit-lab'."

# --- Tạo audit policy template tại /tmp/audit-policy.yaml ---

echo ""
echo "Tạo audit policy template tại /tmp/audit-policy.yaml..."

# Dùng tee để tránh vấn đề heredoc với set -e
tee /tmp/audit-policy.yaml > /dev/null << 'AUDIT_POLICY'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["secrets"]
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
    - group: ""
      resources: ["endpoints", "services", "services/status"]
  - level: None
    users: ["system:unsecured"]
    namespaces: ["kube-system"]
    verbs: ["get"]
    resources:
    - group: ""
      resources: ["configmaps"]
  - level: None
    users: ["kubelet"]
    verbs: ["get"]
    resources:
    - group: ""
      resources: ["nodes", "nodes/status"]
  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get"]
    resources:
    - group: ""
      resources: ["nodes", "nodes/status"]
  - level: Metadata
    omitStages:
    - "RequestReceived"
AUDIT_POLICY

# Xác minh file được tạo đúng
if [ "$(wc -l < /tmp/audit-policy.yaml)" -lt 5 ]; then
  echo "[ERROR] File /tmp/audit-policy.yaml bị lỗi khi tạo."
  exit 1
fi

echo "[OK] Audit policy template đã được tạo tại /tmp/audit-policy.yaml."

# --- Tóm tắt ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:  audit-lab"
echo "  Secret:     sample-secret (audit-lab)"
echo "  Template:   /tmp/audit-policy.yaml"
echo ""
echo "Nhiệm vụ của bạn:"
echo "  1. Xem và hiểu audit policy template tại /tmp/audit-policy.yaml"
echo "  2. Sao chép policy lên control-plane node:"
echo "     sudo mkdir -p /etc/kubernetes/audit"
echo "     sudo cp /tmp/audit-policy.yaml /etc/kubernetes/audit/audit-policy.yaml"
echo ""
echo "  3. Chỉnh sửa kube-apiserver manifest để bật audit logging:"
echo "     sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml"
echo ""
echo "     Thêm các flags sau vào spec.containers[0].command:"
echo "       - --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml"
echo "       - --audit-log-path=/var/log/kubernetes/audit/audit.log"
echo "       - --audit-log-maxage=30"
echo "       - --audit-log-maxbackup=10"
echo "       - --audit-log-maxsize=100"
echo ""
echo "     Thêm volumeMounts và volumes cho audit policy và log directory."
echo "     Xem README.md để biết cấu hình chi tiết."
echo ""
echo "  4. Tạo thư mục log:"
echo "     sudo mkdir -p /var/log/kubernetes/audit"
echo ""
echo "  5. Chờ kube-apiserver restart và kiểm tra audit log:"
echo "     sudo tail -f /var/log/kubernetes/audit/audit.log"
echo ""
echo "Kiểm tra kết quả:"
echo "  bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
