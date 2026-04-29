# Giải pháp mẫu – Lab 2.1: RBAC Least Privilege

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## Bước 1: Xác nhận vấn đề

```bash
# Xem ClusterRoleBinding đang gán cluster-admin cho app-sa
kubectl get clusterrolebinding app-sa-binding -o yaml
```

Output cho thấy `app-sa` được gán `cluster-admin` — toàn quyền trên cluster:

```yaml
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: rbac-lab
```

Xác nhận quyền hiện tại (cả hai đều trả về `yes` — không mong muốn):

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
# yes

kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
# yes  ← đây là vấn đề
```

---

## Bước 2: Xóa ClusterRoleBinding vi phạm

```bash
kubectl delete clusterrolebinding app-sa-binding
```

Sau bước này, `app-sa` không còn quyền nào:

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
# no
```

---

## Bước 3: Tạo Role với quyền tối thiểu

Tạo Role `pod-reader` chỉ cho phép `get`, `list`, `watch` pods trong namespace `rbac-lab`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: rbac-lab
rules:
- apiGroups: [""]        # "" = core API group (pods, services, configmaps, v.v.)
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

Áp dụng:

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

---

## Bước 4: Tạo RoleBinding

Gắn Role `pod-reader` với ServiceAccount `app-sa`:

```yaml
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
```

Áp dụng:

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

---

## Bước 5: Xác minh kết quả

```bash
# Phải trả về "yes"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
# yes ✓

# Phải trả về "no"
kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
# no ✓

# Phải trả về "no" (không có quyền trên namespace khác)
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n default
# no ✓

# Liệt kê tất cả quyền của app-sa trong rbac-lab
kubectl auth can-i --list \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
```

Chạy verify script để xác nhận tất cả tiêu chí:

```bash
bash verify.sh
```

---

## Tóm tắt

| Bước | Hành động | Lệnh |
|------|-----------|------|
| 1 | Xóa ClusterRoleBinding vi phạm | `kubectl delete clusterrolebinding app-sa-binding` |
| 2 | Tạo Role với quyền tối thiểu | `kubectl apply -f role-pod-reader.yaml` |
| 3 | Tạo RoleBinding | `kubectl apply -f rolebinding-app-sa.yaml` |
| 4 | Xác minh | `kubectl auth can-i list/delete pods --as=...` |

---

## Tham khảo

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [RBAC Good Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
