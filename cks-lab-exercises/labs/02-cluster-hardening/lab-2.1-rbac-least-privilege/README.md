# Lab 2.1 – RBAC Least Privilege

**Domain:** Cluster Hardening (15%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Xác định ClusterRoleBinding đang gán quyền quá rộng (`cluster-admin`) cho ServiceAccount
- Xóa ClusterRoleBinding vi phạm nguyên tắc least-privilege
- Tạo Role chỉ cho phép `get`, `list`, `watch` pods trong namespace `rbac-lab`
- Tạo RoleBinding gắn Role mới với ServiceAccount `app-sa`
- Xác minh quyền bằng lệnh `kubectl auth can-i`

---

## Lý thuyết

### RBAC là gì?

**RBAC (Role-Based Access Control)** là cơ chế phân quyền trong Kubernetes — kiểm soát **ai** được làm **gì** với **tài nguyên** nào. Thay vì cấp quyền trực tiếp cho từng user, RBAC dùng **Role** làm trung gian.

Mô hình RBAC gồm 3 thành phần:
```
Subject (Ai?)  →  RoleBinding  →  Role (Làm gì?)  →  Resource (Với gì?)
```

- **Subject**: User, Group, hoặc ServiceAccount
- **Role/ClusterRole**: Tập hợp các quyền (verbs trên resources)
- **RoleBinding/ClusterRoleBinding**: Gắn Role với Subject

### Role vs ClusterRole

| | Role | ClusterRole |
|---|---|---|
| Phạm vi | Một namespace | Toàn cluster |
| Dùng cho | Tài nguyên trong namespace (pods, secrets...) | Tài nguyên cluster-wide (nodes, PV...) |
| Binding | RoleBinding | ClusterRoleBinding (hoặc RoleBinding) |

> **Tip:** Dùng `Role + RoleBinding` khi ứng dụng chỉ cần quyền trong namespace của nó. Chỉ dùng `ClusterRole` khi thực sự cần quyền cluster-wide.

### Verbs và Resources

```yaml
rules:
- apiGroups: [""]          # "" = core API group (pods, services, secrets...)
  resources: ["pods"]      # Loại tài nguyên
  verbs: ["get", "list"]   # Hành động được phép
```

Các verbs phổ biến:

| Verb | Ý nghĩa | HTTP method tương đương |
|------|---------|------------------------|
| `get` | Đọc một resource | GET |
| `list` | Liệt kê nhiều resource | GET (collection) |
| `watch` | Theo dõi thay đổi realtime | GET (watch) |
| `create` | Tạo mới | POST |
| `update` | Cập nhật toàn bộ | PUT |
| `patch` | Cập nhật một phần | PATCH |
| `delete` | Xóa | DELETE |
| `*` | Tất cả verbs | ⚠️ Tránh dùng trong production |

### Nguyên tắc Least Privilege

**Least Privilege** = chỉ cấp đúng những quyền cần thiết, không hơn.

❌ **Sai:** Cấp `cluster-admin` cho ServiceAccount của ứng dụng web
✅ **Đúng:** Chỉ cấp `get, list` trên `pods` trong namespace của ứng dụng

Tại sao quan trọng? Nếu ứng dụng bị compromise (RCE vulnerability), kẻ tấn công chỉ có thể làm những gì ServiceAccount được phép — không thể leo thang lên toàn cluster.

### Kiểm tra quyền với kubectl auth can-i

```bash
# Kiểm tra quyền của user hiện tại
kubectl auth can-i list pods -n default

# Kiểm tra quyền của ServiceAccount (impersonate)
kubectl auth can-i list pods \
  --as=system:serviceaccount:my-ns:my-sa \
  -n my-ns

# Liệt kê tất cả quyền của một identity
kubectl auth can-i --list \
  --as=system:serviceaccount:my-ns:my-sa \
  -n my-ns
```

### Tìm ClusterRoleBinding nguy hiểm

```bash
# Tìm tất cả binding gán cluster-admin
kubectl get clusterrolebinding -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'

# Tìm binding có wildcard verb *
kubectl get clusterrole -o json | \
  jq '.items[] | select(.rules[]?.verbs[]? == "*") | .metadata.name'
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty. Trong quá trình audit cluster, bạn phát hiện ServiceAccount `app-sa` trong namespace `rbac-lab` đang được gán ClusterRole `cluster-admin` thông qua ClusterRoleBinding `app-sa-binding`. Đây là vi phạm nghiêm trọng nguyên tắc least-privilege — ứng dụng chỉ cần đọc danh sách pod trong namespace của nó, nhưng lại có toàn quyền trên toàn cluster.

Nhiệm vụ của bạn là:
1. Tìm và xóa ClusterRoleBinding `app-sa-binding` đang gán `cluster-admin` cho `app-sa`
2. Tạo Role mới chỉ cho phép `get/list/watch` pods trong namespace `rbac-lab`
3. Tạo RoleBinding gắn Role đó với ServiceAccount `app-sa`
4. Xác minh `app-sa` có thể list pods nhưng không thể xóa pods

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền tạo/xóa Role, RoleBinding, ClusterRoleBinding

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra cấu hình hiện tại

```bash
# Xem ClusterRoleBinding đang tồn tại
kubectl get clusterrolebinding app-sa-binding -o yaml

# Xác nhận app-sa đang có cluster-admin
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab

kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
```

Cả hai lệnh trên đều trả về `yes` — đây là vấn đề cần sửa.

### Bước 2: Xóa ClusterRoleBinding vi phạm

```bash
kubectl delete clusterrolebinding app-sa-binding
```

### Bước 3: Tạo Role với quyền tối thiểu

Tạo Role chỉ cho phép `get`, `list`, `watch` pods trong namespace `rbac-lab`:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: rbac-lab
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF
```

### Bước 4: Tạo RoleBinding

Gắn Role `pod-reader` với ServiceAccount `app-sa`:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-sa-pod-reader
  namespace: rbac-lab
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: rbac-lab
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Bước 5: Xác minh kết quả

```bash
# Phải trả về "yes"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab

# Phải trả về "no"
kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab

# Chạy verify script
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] ClusterRoleBinding `app-sa-binding` không còn gán `cluster-admin` cho `app-sa`
- [ ] `kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab` trả về `yes`
- [ ] `kubectl auth can-i delete pods --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab` trả về `no`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cách tìm ClusterRoleBinding của một ServiceAccount</summary>

Dùng lệnh sau để tìm tất cả ClusterRoleBinding liên quan đến một ServiceAccount:

```bash
kubectl get clusterrolebinding -o json | \
  jq '.items[] | select(.subjects[]? | .kind=="ServiceAccount" and .name=="app-sa") | .metadata.name'
```

Hoặc đơn giản hơn:

```bash
kubectl get clusterrolebinding app-sa-binding -o yaml
```

</details>

<details>
<summary>Gợi ý 2: Role vs ClusterRole — khi nào dùng cái nào?</summary>

- **Role**: Phạm vi namespace — chỉ cấp quyền trong một namespace cụ thể. Dùng khi ứng dụng chỉ cần truy cập tài nguyên trong namespace của nó.
- **ClusterRole**: Phạm vi cluster — cấp quyền trên toàn cluster hoặc cho tài nguyên không thuộc namespace (node, PV, v.v.).

Trong bài này, `app-sa` chỉ cần đọc pods trong `rbac-lab` → dùng **Role** là đúng.

</details>

<details>
<summary>Gợi ý 3: Cách kiểm tra quyền với kubectl auth can-i</summary>

```bash
# Kiểm tra quyền của ServiceAccount
kubectl auth can-i <verb> <resource> \
  --as=system:serviceaccount:<namespace>:<sa-name> \
  -n <namespace>

# Ví dụ:
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab

# Liệt kê tất cả quyền của một identity
kubectl auth can-i --list \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
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

### Tại sao cluster-admin cho ServiceAccount là nguy hiểm?

ClusterRole `cluster-admin` cấp **toàn quyền** trên mọi tài nguyên trong cluster — tương đương với `root` trên Linux. Nếu ứng dụng bị compromise (ví dụ: RCE vulnerability), kẻ tấn công có thể:
- Đọc tất cả Secret trong mọi namespace (bao gồm credentials, API keys)
- Xóa hoặc sửa đổi bất kỳ workload nào
- Tạo pod với `privileged: true` để escape ra host
- Thao túng RBAC để duy trì quyền truy cập

### Nguyên tắc Least Privilege trong RBAC

Mỗi ServiceAccount chỉ nên có đúng những quyền cần thiết để thực hiện chức năng của nó:

| Ứng dụng cần | Quyền cấp |
|---|---|
| Đọc danh sách pod | `get`, `list`, `watch` trên `pods` |
| Cập nhật ConfigMap | `get`, `update` trên `configmaps` |
| Tạo Job | `create` trên `jobs` |

### Role vs RoleBinding vs ClusterRole vs ClusterRoleBinding

```
Role          → quyền trong 1 namespace
ClusterRole   → quyền trên toàn cluster

RoleBinding        → gắn Role/ClusterRole vào subject, phạm vi 1 namespace
ClusterRoleBinding → gắn ClusterRole vào subject, phạm vi toàn cluster
```

**Lưu ý:** Dùng ClusterRole + RoleBinding (không phải ClusterRoleBinding) khi muốn tái sử dụng ClusterRole nhưng giới hạn phạm vi trong một namespace.

---

## Tham khảo

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [kubectl auth can-i](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/)
- [CKS Exam Curriculum – Cluster Hardening](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- [RBAC Good Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
