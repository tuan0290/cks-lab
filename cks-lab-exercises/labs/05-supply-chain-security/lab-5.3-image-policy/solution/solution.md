# Giải pháp – Lab 5.3 Image Policy Webhook

## Bước 1: Cài đặt OPA Gatekeeper

```bash
# Cài đặt Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Chờ Gatekeeper sẵn sàng
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

## Bước 2: Apply ConstraintTemplate

```bash
# Xem template đã được tạo bởi setup.sh
cat /tmp/allowed-repos-template.yaml

# Apply ConstraintTemplate
kubectl apply -f /tmp/allowed-repos-template.yaml
```

Nội dung ConstraintTemplate:
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

```bash
# Xác minh ConstraintTemplate đã được tạo
kubectl get constrainttemplate k8sallowedrepos
```

## Bước 3: Tạo Constraint

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
```

```bash
# Xác minh Constraint đã được tạo
kubectl get k8sallowedrepos allowed-repos
kubectl describe k8sallowedrepos allowed-repos
```

## Bước 4: Kiểm tra policy hoạt động

```bash
# Test 1: Pod từ registry được phép (phải thành công)
kubectl run allowed-pod \
  --image=docker.io/library/nginx:1.25-alpine \
  --namespace=policy-lab \
  --restart=Never

# Xác minh pod được tạo
kubectl get pod allowed-pod -n policy-lab
```

```bash
# Test 2: Pod từ registry không được phép (phải bị từ chối)
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

## Bước 5: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] ConstraintTemplate 'k8sallowedrepos' tồn tại trong cluster
[PASS] Constraint K8sAllowedRepos tồn tại trong cluster
[PASS] Namespace 'policy-lab' tồn tại trong cluster
---
Kết quả: 3/3 tiêu chí đạt
```

## Tóm tắt lệnh Gatekeeper quan trọng

| Lệnh | Mục đích |
|------|----------|
| `kubectl get constrainttemplate` | Liệt kê tất cả ConstraintTemplate |
| `kubectl get k8sallowedrepos` | Liệt kê Constraint của loại K8sAllowedRepos |
| `kubectl describe k8sallowedrepos <name>` | Xem chi tiết Constraint và violations |
| `kubectl get constrainttemplate -o yaml` | Xem Rego policy |

## Kiểm tra violations

```bash
# Xem các violations hiện tại
kubectl describe k8sallowedrepos allowed-repos | grep -A 20 "Violations:"

# Hoặc
kubectl get k8sallowedrepos allowed-repos -o jsonpath='{.status.violations}' | jq .
```

## Giải thích Rego policy

```rego
package k8sallowedrepos

violation[{"msg": msg}] {
  # Lấy từng container trong pod
  container := input.review.object.spec.containers[_]
  
  # Kiểm tra xem image có bắt đầu bằng repo được phép không
  satisfied := [good | 
    repo = input.parameters.repos[_]
    good = startswith(container.image, repo)
  ]
  
  # Nếu không có repo nào thỏa mãn → violation
  not any(satisfied)
  
  # Tạo thông báo lỗi
  msg := sprintf("container <%v> has an invalid image repo <%v>, allowed repos are %v",
    [container.name, container.image, input.parameters.repos])
}
```

## Lưu ý về thứ tự kiểm tra

Gatekeeper kiểm tra image prefix, vì vậy:
- `docker.io/library/nginx:1.25-alpine` → PASS (bắt đầu bằng `docker.io/library`)
- `nginx:1.25-alpine` → FAIL (không có prefix registry rõ ràng)
- `registry.k8s.io/pause:3.9` → PASS (bắt đầu bằng `registry.k8s.io`)
- `gcr.io/google-containers/pause:3.1` → FAIL

Để cho phép short image names như `nginx:1.25-alpine`, thêm `docker.io/library` vào repos list (Docker Hub mặc định resolve `nginx` thành `docker.io/library/nginx`).
