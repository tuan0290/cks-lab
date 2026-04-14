# Lab 5.3 – Image Policy Webhook

**Domain:** Supply Chain Security (20%)
**Thời gian ước tính:** 30 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Cấu hình OPA/Gatekeeper ConstraintTemplate và Constraint để kiểm soát registry image
- Chỉ cho phép image từ registry `registry.k8s.io` và `docker.io/library`
- Xác minh pod sử dụng image từ registry không được phép bị từ chối

---

## Lý thuyết

### Tại sao cần kiểm soát image registry?

Nếu không kiểm soát, developer có thể deploy image từ bất kỳ registry nào — kể cả registry không tin cậy, có thể chứa malware. **Image Policy** đảm bảo chỉ image từ registry được phê duyệt mới được deploy.

### OPA/Gatekeeper là gì?

**OPA (Open Policy Agent)** là policy engine mã nguồn mở. **Gatekeeper** là Kubernetes admission controller tích hợp OPA, cho phép viết policy bằng ngôn ngữ **Rego**.

Gatekeeper hoạt động như **ValidatingAdmissionWebhook** — được gọi bởi API server trước khi tạo/cập nhật resource:

```
kubectl apply → API Server → Gatekeeper Webhook → OPA Policy → Allow/Deny
```

### ConstraintTemplate và Constraint

Gatekeeper dùng 2 loại resource:

**ConstraintTemplate**: Định nghĩa loại policy (schema + Rego logic)
```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sallowedrepos
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRepos
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sallowedrepos
      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        satisfied := [good | repo = input.parameters.repos[_]; good = startswith(container.image, repo)]
        not any(satisfied)
        msg := sprintf("Image not from allowed repo: %v", [container.image])
      }
```

**Constraint**: Instance của ConstraintTemplate với tham số cụ thể
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-repos
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - production
  parameters:
    repos:
    - "registry.k8s.io"
    - "docker.io/library"
```

### Kiểm tra Gatekeeper violations

```bash
# Xem tất cả violations
kubectl get constraint -o json | jq '.items[].status.violations'

# Xem violations của một constraint cụ thể
kubectl describe k8sallowedrepos allowed-repos
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty đang triển khai chính sách kiểm soát image registry. Yêu cầu bảo mật là chỉ cho phép deploy image từ các registry đã được phê duyệt: `registry.k8s.io` và `docker.io/library`. Bất kỳ image nào từ registry khác phải bị từ chối bởi admission controller.

Nhiệm vụ của bạn là:
1. Cài đặt OPA/Gatekeeper trên cluster (nếu chưa có)
2. Tạo ConstraintTemplate `K8sAllowedRepos` định nghĩa logic kiểm tra
3. Tạo Constraint áp dụng policy cho namespace `policy-lab`
4. Xác minh pod từ registry không được phép bị từ chối

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền cluster-admin để cài đặt Gatekeeper
- Kết nối internet để pull Gatekeeper image

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Cài đặt OPA Gatekeeper

```bash
# Cài đặt Gatekeeper phiên bản mới nhất
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Chờ Gatekeeper sẵn sàng
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager \
  -n gatekeeper-system --timeout=120s
```

### Bước 2: Tạo ConstraintTemplate

```bash
# Xem template đã được tạo bởi setup.sh
cat /tmp/allowed-repos-template.yaml

# Apply ConstraintTemplate
kubectl apply -f /tmp/allowed-repos-template.yaml

# Xác minh ConstraintTemplate đã được tạo
kubectl get constrainttemplate k8sallowedrepos
```

### Bước 3: Tạo Constraint

```bash
# Tạo Constraint áp dụng policy
kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-repos
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - policy-lab
  parameters:
    repos:
    - "registry.k8s.io"
    - "docker.io/library"
EOF
```

### Bước 4: Kiểm tra policy hoạt động

```bash
# Thử deploy pod từ registry được phép (phải thành công)
kubectl run allowed-pod \
  --image=docker.io/library/nginx:1.25-alpine \
  --namespace=policy-lab \
  --restart=Never

# Thử deploy pod từ registry không được phép (phải bị từ chối)
kubectl run denied-pod \
  --image=gcr.io/google-containers/pause:3.1 \
  --namespace=policy-lab \
  --restart=Never
# Mong đợi: Error from server: admission webhook denied the request
```

### Bước 5: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] ConstraintTemplate `K8sAllowedRepos` tồn tại trong cluster (hoặc ImagePolicyWebhook được cấu hình)
- [ ] Constraint `allowed-repos` tồn tại và áp dụng cho namespace `policy-lab`
- [ ] Namespace `policy-lab` tồn tại trong cluster

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cấu trúc ConstraintTemplate</summary>

ConstraintTemplate định nghĩa:
1. Schema của Constraint (các tham số đầu vào)
2. Rego policy logic để kiểm tra

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sallowedrepos
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
```

</details>

<details>
<summary>Gợi ý 2: Kiểm tra Gatekeeper đã cài đặt chưa</summary>

```bash
# Kiểm tra namespace gatekeeper-system
kubectl get namespace gatekeeper-system

# Kiểm tra pods
kubectl get pods -n gatekeeper-system

# Kiểm tra webhook configurations
kubectl get validatingwebhookconfigurations | grep gatekeeper
```

</details>

<details>
<summary>Gợi ý 3: Xử lý lỗi khi Gatekeeper chưa sẵn sàng</summary>

Nếu Gatekeeper chưa sẵn sàng, Constraint sẽ không được enforce. Chờ tất cả pods trong `gatekeeper-system` ở trạng thái Running:

```bash
kubectl get pods -n gatekeeper-system -w
```

Nếu gặp lỗi webhook timeout, kiểm tra:
```bash
kubectl describe validatingwebhookconfiguration gatekeeper-validating-webhook-configuration
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### OPA Gatekeeper là gì?

OPA (Open Policy Agent) Gatekeeper là một admission controller cho Kubernetes, cho phép định nghĩa và enforce policy bằng ngôn ngữ Rego. Gatekeeper hoạt động như một ValidatingAdmissionWebhook — được gọi bởi API server trước khi tạo/cập nhật resource.

### ConstraintTemplate vs Constraint

- **ConstraintTemplate**: Định nghĩa loại policy (schema + Rego logic). Giống như "class" trong OOP.
- **Constraint**: Instance của ConstraintTemplate với tham số cụ thể. Giống như "object" trong OOP.

### Tại sao kiểm soát registry quan trọng?

- Ngăn chặn deploy image từ nguồn không tin cậy
- Đảm bảo image đã qua quét bảo mật (nếu registry nội bộ có tích hợp scanning)
- Giảm rủi ro supply chain attack (typosquatting, image poisoning)
- Tuân thủ chính sách bảo mật của tổ chức

### ImagePolicyWebhook (thay thế)

Kubernetes cũng có built-in `ImagePolicyWebhook` admission plugin:
```yaml
# /etc/kubernetes/admission-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/image-policy-webhook.kubeconfig
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
```

---

## Tham khảo

- [OPA Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/)
- [Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library)
- [Kubernetes ImagePolicyWebhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook)
- [CKS Exam – Supply Chain Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
