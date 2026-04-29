#!/bin/bash
# Lab 6.2 – Audit Log Analysis
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 6.2 – Audit Log Analysis"
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

if ! command -v jq &>/dev/null; then
  echo "[WARN] jq không tìm thấy."
  echo "       Cài đặt jq: apt-get install jq hoặc yum install jq"
  echo "[INFO] Tiếp tục tạo môi trường lab..."
else
  echo "[OK] jq đã được cài đặt: $(jq --version)"
fi

# --- Tạo namespace audit-analysis-lab ---

echo ""
echo "Tạo namespace audit-analysis-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: audit-analysis-lab
  labels:
    lab: "6.2"
    purpose: audit-log-analysis
EOF

echo "[OK] Namespace 'audit-analysis-lab' đã được tạo."

# --- Tạo sample audit log file ---

echo ""
echo "Tạo sample audit log tại /tmp/sample-audit.log..."

cat > /tmp/sample-audit.log <<'EOF'
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"a1b2c3d4-0001","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/production/secrets/db-password","verb":"get","user":{"username":"alice","uid":"alice-uid","groups":["system:authenticated","developers"]},"sourceIPs":["10.0.0.5"],"objectRef":{"resource":"secrets","namespace":"production","name":"db-password","apiVersion":"v1"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-01-15T08:30:00Z","stageTimestamp":"2024-01-15T08:30:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"a1b2c3d4-0002","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/production/pods","verb":"list","user":{"username":"bob","uid":"bob-uid","groups":["system:authenticated"]},"sourceIPs":["10.0.0.6"],"objectRef":{"resource":"pods","namespace":"production","apiVersion":"v1"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-01-15T08:31:00Z","stageTimestamp":"2024-01-15T08:31:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"a1b2c3d4-0003","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/production/secrets","verb":"list","user":{"username":"bob","uid":"bob-uid","groups":["system:authenticated"]},"sourceIPs":["10.0.0.6"],"objectRef":{"resource":"secrets","namespace":"production","apiVersion":"v1"},"responseStatus":{"code":403,"reason":"Forbidden","message":"bob cannot list secrets in namespace production"},"requestReceivedTimestamp":"2024-01-15T08:32:00Z","stageTimestamp":"2024-01-15T08:32:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"a1b2c3d4-0004","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/production/secrets/api-key","verb":"get","user":{"username":"alice","uid":"alice-uid","groups":["system:authenticated","developers"]},"sourceIPs":["10.0.0.5"],"objectRef":{"resource":"secrets","namespace":"production","name":"api-key","apiVersion":"v1"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-01-15T08:33:00Z","stageTimestamp":"2024-01-15T08:33:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"a1b2c3d4-0005","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/production/pods/web-pod/exec","verb":"create","user":{"username":"charlie","uid":"charlie-uid","groups":["system:authenticated","ops-team"]},"sourceIPs":["10.0.0.7"],"objectRef":{"resource":"pods","namespace":"production","name":"web-pod","subresource":"exec","apiVersion":"v1"},"responseStatus":{"code":101},"requestReceivedTimestamp":"2024-01-15T08:35:00Z","stageTimestamp":"2024-01-15T08:35:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"a1b2c3d4-0006","stage":"ResponseComplete","requestURI":"/apis/apps/v1/namespaces/production/deployments","verb":"create","user":{"username":"bob","uid":"bob-uid","groups":["system:authenticated"]},"sourceIPs":["10.0.0.6"],"objectRef":{"resource":"deployments","namespace":"production","apiVersion":"apps/v1"},"responseStatus":{"code":403,"reason":"Forbidden","message":"bob cannot create deployments in namespace production"},"requestReceivedTimestamp":"2024-01-15T08:36:00Z","stageTimestamp":"2024-01-15T08:36:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"a1b2c3d4-0007","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/production/configmaps","verb":"list","user":{"username":"alice","uid":"alice-uid","groups":["system:authenticated","developers"]},"sourceIPs":["10.0.0.5"],"objectRef":{"resource":"configmaps","namespace":"production","apiVersion":"v1"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-01-15T08:37:00Z","stageTimestamp":"2024-01-15T08:37:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"a1b2c3d4-0008","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/kube-system/secrets/admin-token","verb":"get","user":{"username":"alice","uid":"alice-uid","groups":["system:authenticated","developers"]},"sourceIPs":["10.0.0.5"],"objectRef":{"resource":"secrets","namespace":"kube-system","name":"admin-token","apiVersion":"v1"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-01-15T08:38:00Z","stageTimestamp":"2024-01-15T08:38:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"a1b2c3d4-0009","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/production/pods/db-pod/exec","verb":"create","user":{"username":"charlie","uid":"charlie-uid","groups":["system:authenticated","ops-team"]},"sourceIPs":["10.0.0.7"],"objectRef":{"resource":"pods","namespace":"production","name":"db-pod","subresource":"exec","apiVersion":"v1"},"responseStatus":{"code":101},"requestReceivedTimestamp":"2024-01-15T08:40:00Z","stageTimestamp":"2024-01-15T08:40:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"a1b2c3d4-0010","stage":"ResponseComplete","requestURI":"/apis/rbac.authorization.k8s.io/v1/clusterrolebindings","verb":"create","user":{"username":"bob","uid":"bob-uid","groups":["system:authenticated"]},"sourceIPs":["10.0.0.6"],"objectRef":{"resource":"clusterrolebindings","apiVersion":"rbac.authorization.k8s.io/v1"},"responseStatus":{"code":403,"reason":"Forbidden","message":"bob cannot create clusterrolebindings"},"requestReceivedTimestamp":"2024-01-15T08:41:00Z","stageTimestamp":"2024-01-15T08:41:00Z"}
EOF

echo "[OK] File /tmp/sample-audit.log đã được tạo (10 events)."

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: audit-analysis-lab"
echo "  File:      /tmp/sample-audit.log (10 audit events)"
echo ""
echo "NHIỆM VỤ:"
echo "  Phân tích /tmp/sample-audit.log và trả lời 3 câu hỏi:"
echo ""
echo "  Q1: User nào đã truy cập Secret?"
echo "       cat /tmp/sample-audit.log | jq -r 'select(.objectRef.resource == \"secrets\") | .user.username' | sort | uniq"
echo ""
echo "  Q2: Request nào bị từ chối 403? (user nào, làm gì?)"
echo "       cat /tmp/sample-audit.log | jq -r 'select(.responseStatus.code == 403) | \"\(.user.username) \(.verb) \(.objectRef.resource)\"'"
echo ""
echo "  Q3: Ai đã exec vào pod nào?"
echo "       cat /tmp/sample-audit.log | jq -r 'select(.objectRef.subresource == \"exec\") | \"\(.user.username) exec \(.objectRef.name)\"'"
echo ""
echo "  Ghi câu trả lời vào /tmp/answers.txt:"
echo "       nano /tmp/answers.txt"
echo ""
echo "  Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
