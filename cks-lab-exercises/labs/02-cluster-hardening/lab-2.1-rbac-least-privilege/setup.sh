#!/bin/bash
# Lab 2.1 – RBAC Least Privilege
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 2.1 – RBAC Least Privilege"
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

# --- Tạo namespace rbac-lab ---

echo ""
echo "Tạo namespace rbac-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: rbac-lab
  labels:
    lab: "2.1"
    purpose: rbac-least-privilege
EOF

echo "[OK] Namespace 'rbac-lab' đã được tạo."

# --- Tạo ServiceAccount app-sa ---

echo ""
echo "Tạo ServiceAccount app-sa trong rbac-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: rbac-lab
  labels:
    lab: "2.1"
EOF

echo "[OK] ServiceAccount 'app-sa' đã được tạo trong namespace 'rbac-lab'."

# --- Tạo ClusterRoleBinding cố ý quá rộng (intentionally over-privileged) ---

echo ""
echo "Tạo ClusterRoleBinding app-sa-binding (cố ý gán cluster-admin — đây là vấn đề cần sửa)..."

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: app-sa-binding
  labels:
    lab: "2.1"
    intentionally-overprivileged: "true"
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: rbac-lab
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo "[OK] ClusterRoleBinding 'app-sa-binding' đã được tạo (gán cluster-admin cho app-sa)."

# --- Tạo một pod mẫu trong rbac-lab để có tài nguyên kiểm tra ---

echo ""
echo "Tạo pod mẫu trong rbac-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sample-pod
  namespace: rbac-lab
  labels:
    app: sample
    lab: "2.1"
spec:
  containers:
  - name: nginx
    image: nginx:1.25-alpine
  serviceAccountName: app-sa
EOF

echo "[OK] Pod 'sample-pod' đã được tạo trong namespace 'rbac-lab'."

# --- Tóm tắt ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:          rbac-lab"
echo "  ServiceAccount:     app-sa (rbac-lab)"
echo "  ClusterRoleBinding: app-sa-binding → cluster-admin (QUÁ RỘNG!)"
echo "  Pod:                sample-pod (rbac-lab)"
echo ""
echo "Vấn đề cần giải quyết:"
echo "  ClusterRoleBinding 'app-sa-binding' đang gán ClusterRole 'cluster-admin'"
echo "  cho ServiceAccount 'app-sa'. Đây là vi phạm nguyên tắc least-privilege."
echo ""
echo "  Xác nhận vấn đề:"
echo "    kubectl get clusterrolebinding app-sa-binding -o yaml"
echo "    kubectl auth can-i delete pods \\"
echo "      --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab"
echo "    # Kết quả: yes (không mong muốn!)"
echo ""
echo "Bước tiếp theo:"
echo "  1. Đọc README.md để hiểu yêu cầu bài lab"
echo "  2. Xóa ClusterRoleBinding vi phạm và tạo Role/RoleBinding phù hợp"
echo "  3. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
