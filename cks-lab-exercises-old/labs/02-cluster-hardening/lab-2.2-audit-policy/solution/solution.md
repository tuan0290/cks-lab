# Giải pháp mẫu – Lab 2.2: Audit Policy

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## Bước 1: Tạo Audit Policy file

Trên control-plane node, tạo thư mục và policy file:

```bash
sudo mkdir -p /etc/kubernetes/audit
```

Tạo file `/etc/kubernetes/audit/audit-policy.yaml` với nội dung sau:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Rule 1: Ghi đầy đủ RequestResponse cho Secret
  # Bắt tất cả thao tác (get, list, create, update, delete, watch) trên secrets
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["secrets"]

  # Rule 2-5: Loại trừ system noise để giảm log không cần thiết
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

  # Rule cuối: Ghi Metadata cho tất cả thao tác còn lại
  # omitStages loại bỏ stage RequestReceived để giảm duplicate events
  - level: Metadata
    omitStages:
    - "RequestReceived"
```

---

## Bước 2: Cấu hình kube-apiserver

### 2a. Backup manifest hiện tại

```bash
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml \
  /etc/kubernetes/kube-apiserver.yaml.bak
```

### 2b. Tạo thư mục log

```bash
sudo mkdir -p /var/log/kubernetes/audit
```

### 2c. Chỉnh sửa kube-apiserver manifest

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Thêm các flags vào phần `spec.containers[0].command`:

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    # ... các flags hiện có ...
    - --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxage=30
    - --audit-log-maxbackup=10
    - --audit-log-maxsize=100
```

Thêm volumeMounts vào `spec.containers[0].volumeMounts`:

```yaml
    volumeMounts:
    # ... các volumeMounts hiện có ...
    - mountPath: /etc/kubernetes/audit
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit
      name: audit-log
```

Thêm volumes vào `spec.volumes`:

```yaml
  volumes:
  # ... các volumes hiện có ...
  - hostPath:
      path: /etc/kubernetes/audit
      type: DirectoryOrCreate
    name: audit-policy
  - hostPath:
      path: /var/log/kubernetes/audit
      type: DirectoryOrCreate
    name: audit-log
```

### 2d. Chờ kube-apiserver restart

Sau khi lưu file, kubelet tự động phát hiện thay đổi và restart kube-apiserver (khoảng 30-60 giây):

```bash
# Theo dõi quá trình restart
watch kubectl get pods -n kube-system -l component=kube-apiserver

# Hoặc chờ cho đến khi Ready
kubectl wait --for=condition=Ready pod -l component=kube-apiserver \
  -n kube-system --timeout=120s
```

---

## Bước 3: Xác minh audit log được ghi

### 3a. Thực hiện thao tác trên Secret để tạo audit event

```bash
# Đọc Secret — sẽ tạo audit event với level RequestResponse
kubectl get secret sample-secret -n audit-lab
kubectl get secret sample-secret -n audit-lab -o yaml

# Tạo Secret mới
kubectl create secret generic test-secret \
  --from-literal=key=value -n audit-lab

# Xóa Secret
kubectl delete secret test-secret -n audit-lab
```

### 3b. Xem audit log

```bash
# Xem log mới nhất
sudo tail -20 /var/log/kubernetes/audit/audit.log

# Format JSON đẹp hơn
sudo tail -5 /var/log/kubernetes/audit/audit.log | python3 -m json.tool

# Lọc các event liên quan đến Secret
sudo grep '"resource":"secrets"' /var/log/kubernetes/audit/audit.log | \
  python3 -c "
import sys, json
for line in sys.stdin:
    event = json.loads(line)
    print(f\"verb={event.get('verb')} level={event.get('level')} \
user={event.get('user',{}).get('username')} \
resource={event.get('objectRef',{}).get('resource')}\")
"
```

### 3c. Ví dụ audit log entry cho Secret

Khi đọc Secret với level `RequestResponse`, audit log sẽ có dạng:

```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "RequestResponse",
  "auditID": "a3b4c5d6-...",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/audit-lab/secrets/sample-secret",
  "verb": "get",
  "user": {
    "username": "kubernetes-admin",
    "groups": ["system:masters", "system:authenticated"]
  },
  "sourceIPs": ["192.168.1.100"],
  "objectRef": {
    "resource": "secrets",
    "namespace": "audit-lab",
    "name": "sample-secret",
    "apiVersion": "v1"
  },
  "responseStatus": {
    "code": 200
  },
  "requestObject": null,
  "responseObject": {
    "kind": "Secret",
    "apiVersion": "v1",
    "metadata": {
      "name": "sample-secret",
      "namespace": "audit-lab"
    },
    "data": {
      "username": "YWRtaW4=",
      "password": "cGFzc3dvcmQxMjM=",
      "api-key": "c3VwZXItc2VjcmV0LWFwaS1rZXk="
    },
    "type": "Opaque"
  },
  "requestReceivedTimestamp": "2024-10-15T10:30:00.000000Z",
  "stageTimestamp": "2024-10-15T10:30:00.005000Z"
}
```

Khi thực hiện thao tác khác (ví dụ: list pods) với level `Metadata`:

```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "Metadata",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/audit-lab/pods",
  "verb": "list",
  "user": {
    "username": "kubernetes-admin"
  },
  "objectRef": {
    "resource": "pods",
    "namespace": "audit-lab",
    "apiVersion": "v1"
  },
  "responseStatus": {
    "code": 200
  },
  "requestObject": null,
  "responseObject": null
}
```

Lưu ý: Với level `Metadata`, `requestObject` và `responseObject` đều là `null`.

---

## Bước 4: Phân tích audit log nâng cao

```bash
# Tìm tất cả user đã truy cập Secret
sudo grep '"resource":"secrets"' /var/log/kubernetes/audit/audit.log | \
  python3 -c "
import sys, json
users = set()
for line in sys.stdin:
    event = json.loads(line)
    user = event.get('user', {}).get('username', 'unknown')
    verb = event.get('verb', '')
    ns = event.get('objectRef', {}).get('namespace', '')
    name = event.get('objectRef', {}).get('name', '')
    print(f'{user} {verb} secret/{name} in {ns}')
    users.add(user)
print(f'\nUsers đã truy cập Secret: {users}')
"

# Tìm các request bị từ chối (403)
sudo grep '"code":403' /var/log/kubernetes/audit/audit.log | \
  python3 -c "
import sys, json
for line in sys.stdin:
    event = json.loads(line)
    user = event.get('user', {}).get('username', 'unknown')
    verb = event.get('verb', '')
    resource = event.get('objectRef', {}).get('resource', '')
    print(f'DENIED: {user} tried to {verb} {resource}')
"
```

---

## Tóm tắt

| Bước | Hành động |
|------|-----------|
| 1 | Tạo `/etc/kubernetes/audit/audit-policy.yaml` với rule RequestResponse cho secrets và Metadata cho còn lại |
| 2 | Thêm audit flags vào kube-apiserver manifest |
| 3 | Thêm volumeMounts và volumes cho policy file và log directory |
| 4 | Tạo `/var/log/kubernetes/audit/` và chờ kube-apiserver restart |
| 5 | Xác minh log được ghi bằng cách thực hiện thao tác trên Secret |

---

## Tham khảo

- [Kubernetes Auditing Documentation](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [Audit Policy Reference](https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/)
- [kube-apiserver Audit Flags](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
