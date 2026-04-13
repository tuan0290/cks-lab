#!/bin/bash
# Lab 5.3 – Image Policy Webhook
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 5.3 – Image Policy Webhook"
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

# --- Tạo namespace policy-lab ---

echo ""
echo "Tạo namespace policy-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: policy-lab
  labels:
    lab: "5.3"
    purpose: image-policy
EOF

echo "[OK] Namespace 'policy-lab' đã được tạo."

# --- Tạo ConstraintTemplate YAML tại /tmp/allowed-repos-template.yaml ---

echo ""
echo "Tạo ConstraintTemplate YAML tại /tmp/allowed-repos-template.yaml..."

cat > /tmp/allowed-repos-template.yaml <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sallowedrepos
  annotations:
    description: "Requires container images to begin with a string from the specified list."
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRepos
      validation:
        openAPIV3Schema:
          type: object
          properties:
            repos:
              description: The list of prefixes a container image is allowed to have.
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sallowedrepos

      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        satisfied := [good | repo = input.parameters.repos[_]; good = startswith(container.image, repo)]
        not any(satisfied)
        msg := sprintf("container <%v> has an invalid image repo <%v>, allowed repos are %v",
          [container.name, container.image, input.parameters.repos])
      }

      violation[{"msg": msg}] {
        container := input.review.object.spec.initContainers[_]
        satisfied := [good | repo = input.parameters.repos[_]; good = startswith(container.image, repo)]
        not any(satisfied)
        msg := sprintf("initContainer <%v> has an invalid image repo <%v>, allowed repos are %v",
          [container.name, container.image, input.parameters.repos])
      }
EOF

echo "[OK] File /tmp/allowed-repos-template.yaml đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: policy-lab"
echo "  File:      /tmp/allowed-repos-template.yaml (ConstraintTemplate)"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Cài đặt OPA Gatekeeper (nếu chưa có):"
echo "       kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml"
echo "       kubectl wait --for=condition=Ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=120s"
echo ""
echo "  2. Apply ConstraintTemplate:"
echo "       kubectl apply -f /tmp/allowed-repos-template.yaml"
echo ""
echo "  3. Tạo Constraint:"
echo "       kubectl apply -f - <<EOF"
echo "       apiVersion: constraints.gatekeeper.sh/v1beta1"
echo "       kind: K8sAllowedRepos"
echo "       metadata:"
echo "         name: allowed-repos"
echo "       spec:"
echo "         match:"
echo "           kinds:"
echo "           - apiGroups: [\"\"]"
echo "             kinds: [\"Pod\"]"
echo "           namespaces:"
echo "           - policy-lab"
echo "         parameters:"
echo "           repos:"
echo "           - \"registry.k8s.io\""
echo "           - \"docker.io/library\""
echo "       EOF"
echo ""
echo "  4. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
