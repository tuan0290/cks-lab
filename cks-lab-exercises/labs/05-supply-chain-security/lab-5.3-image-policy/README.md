# Lab 5.3 – Image Policy Webhook

**Domain:** Supply Chain Security (20%)
**Thời gian ước tính:** 30 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Cài đặt OPA/Gatekeeper trên cluster
- Apply ConstraintTemplate `K8sAllowedRepos` (đã được chuẩn bị sẵn bởi setup.sh)
- Tạo Constraint chỉ cho phép image từ `registry.k8s.io` và `docker.io/library` trong namespace `policy-lab`
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
        msg := sprintf("container <%v> has an invalid image repo <%v>, allowed repos are %v",
          [container.name, container.image, input.parameters.repos])
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
    - policy-lab
  parameters:
    repos:
    - "registry.k8s.io"
    - "docker.io/library"
```

### Lưu ý về image prefix

Gatekeeper kiểm tra image theo prefix, vì vậy:
- `docker.io/library/nginx:1.25-alpine` → ✅ PASS
- `nginx:1.25-alpine` → ❌ FAIL (thiếu registry prefix)
- `registry.k8s.io/pause:3.9` → ✅ PASS
- `gcr.io/google-containers/pause:3.1` → ❌ FAIL

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty đang triển khai chính sách kiểm soát image registry. Yêu cầu bảo mật là chỉ cho phép deploy image từ các registry đã được phê duyệt: `registry.k8s.io` và `docker.io/library`. Bất kỳ image nào từ registry khác phải bị từ chối bởi admission controller.

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

Script sẽ tự động:
- Tạo namespace `policy-lab`
- Tạo file `/tmp/allowed-repos-template.yaml` (ConstraintTemplate sẵn sàng để apply)

---

## Các bước thực hiện

### Bước 1: Cài đặt OPA Gatekeeper

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Chờ Gatekeeper sẵn sàng (có thể mất 1-2 phút)
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager \
  -n gatekeeper-system --timeout=120s

# Xác minh pods đang chạy
kubectl get pods -n gatekeeper-system
```

Output mong đợi:
```
NAME                                             READY   STATUS    RESTARTS   AGE
gatekeeper-audit-...                             1/1     Running   0          60s
gatekeeper-controller-manager-...               1/1     Running   0          60s
```

### Bước 2: Apply ConstraintTemplate

File `/tmp/allowed-repos-template.yaml` đã được tạo sẵn bởi `setup.sh`.

```bash
# Xem nội dung template
cat /tmp/allowed-repos-template.yaml

# Apply ConstraintTemplate
kubectl apply -f /tmp/allowed-repos-template.yaml

# Xác minh đã được tạo
kubectl get constrainttemplate k8sallowedrepos
```

### Bước 3: Tạo Constraint

```bash
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

# Xác minh Constraint đã được tạo
kubectl get k8sallowedrepos allowed-repos
```

### Bước 4: Kiểm tra policy hoạt động

```bash
# Test 1: Pod từ registry được phép → phải thành công
kubectl run allowed-pod \
  --image=docker.io/library/nginx:1.25-alpine \
  --namespace=policy-lab \
  --restart=Never

# Test 2: Pod từ registry không được phép → phải bị từ chối
kubectl run denied-pod \
  --image=gcr.io/google-containers/pause:3.1 \
  --namespace=policy-lab \
  --restart=Never
```

Output mong đợi khi bị từ chối:
```
Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request:
[allowed-repos] container <denied-pod> has an invalid image repo <gcr.io/google-containers/pause:3.1>,
allowed repos are ["registry.k8s.io", "docker.io/library"]
```

### Bước 5: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] ConstraintTemplate `k8sallowedrepos` tồn tại trong cluster
- [ ] Constraint `allowed-repos` (kind: K8sAllowedRepos) tồn tại trong cluster
- [ ] Namespace `policy-lab` tồn tại trong cluster

---

## Gợi ý

<details>
<summary>Gợi ý 1: Kiểm tra Gatekeeper đã sẵn sàng chưa</summary>

```bash
# Kiểm tra tất cả pods trong gatekeeper-system
kubectl get pods -n gatekeeper-system

# Theo dõi trạng thái pods
kubectl get pods -n gatekeeper-system -w

# Kiểm tra webhook đã được đăng ký
kubectl get validatingwebhookconfiguration | grep gatekeeper
```

Gatekeeper cần tất cả pods ở trạng thái `Running` trước khi Constraint có hiệu lực.

</details>

<details>
<summary>Gợi ý 2: Constraint chưa enforce ngay lập tức</summary>

Sau khi apply Constraint, Gatekeeper cần vài giây để sync. Nếu test ngay mà không thấy bị từ chối, hãy chờ 10-15 giây rồi thử lại.

```bash
# Kiểm tra trạng thái Constraint
kubectl describe k8sallowedrepos allowed-repos
```

</details>

<details>
<summary>Gợi ý 3: Xử lý lỗi "no matches for kind ConstraintTemplate"</summary>

Nếu gặp lỗi này khi apply ConstraintTemplate, Gatekeeper chưa cài đặt hoặc chưa sẵn sàng:

```bash
# Kiểm tra CRD của Gatekeeper đã tồn tại chưa
kubectl get crd | grep gatekeeper

# Nếu chưa có, cài đặt lại Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
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

### OPA Gatekeeper hoạt động như thế nào?

Gatekeeper đăng ký một `ValidatingAdmissionWebhook` với API server. Khi có request tạo/cập nhật resource, API server gọi webhook của Gatekeeper. Gatekeeper đánh giá request theo các Constraint đang active và trả về Allow hoặc Deny.

### Tại sao cần dùng full registry prefix?

Docker Hub có thể resolve `nginx` thành `docker.io/library/nginx`, nhưng Gatekeeper kiểm tra chuỗi image **trước khi** Docker resolve. Vì vậy phải dùng full prefix `docker.io/library/nginx:1.25-alpine` thay vì `nginx:1.25-alpine`.

### Tại sao kiểm soát registry quan trọng?

- Ngăn chặn deploy image từ nguồn không tin cậy
- Giảm rủi ro supply chain attack (typosquatting, image poisoning)
- Đảm bảo image đã qua quét bảo mật nếu dùng registry nội bộ
- Tuân thủ chính sách bảo mật của tổ chức

---

## Tham khảo

- [OPA Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/)
- [Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library)
- [Kubernetes ImagePolicyWebhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook)
- [CKS Exam – Supply Chain Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
