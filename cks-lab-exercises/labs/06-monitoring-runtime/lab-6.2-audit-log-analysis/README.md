# Lab 6.2 – Audit Log Analysis

**Domain:** Monitoring, Logging and Runtime Security (20%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Phân tích Kubernetes audit log để tìm các sự kiện bảo mật quan trọng
- Xác định user đã truy cập Secret
- Tìm các request bị từ chối với mã lỗi 403
- Phát hiện thao tác `exec` vào pod

---

## Bối cảnh

Bạn là kỹ sư bảo mật đang điều tra một sự cố bảo mật trong cluster Kubernetes. Team của bạn đã thu thập được audit log từ kube-apiserver. Nhiệm vụ của bạn là phân tích log này để trả lời các câu hỏi điều tra.

Nhiệm vụ của bạn là:
1. Phân tích file `/tmp/sample-audit.log` bằng `jq`
2. Tìm user đã truy cập Secret
3. Tìm các request bị từ chối với mã 403
4. Tìm thao tác exec vào pod
5. Ghi câu trả lời vào `/tmp/answers.txt`

---

## Yêu cầu môi trường

- `jq` đã được cài đặt: [https://jqlang.github.io/jq/](https://jqlang.github.io/jq/)
- `kubectl` đã được cấu hình và kết nối đến cluster

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Xem cấu trúc audit log

```bash
# Xem một event trong audit log
cat /tmp/sample-audit.log | head -1 | jq .

# Đếm tổng số events
cat /tmp/sample-audit.log | wc -l
```

### Bước 2: Tìm user đã truy cập Secret

```bash
# Tìm tất cả events liên quan đến Secret
cat /tmp/sample-audit.log | jq -r 'select(.objectRef.resource == "secrets") | 
  "\(.user.username) \(.verb) \(.objectRef.name) in \(.objectRef.namespace)"'

# Tìm user cụ thể đã GET secret
cat /tmp/sample-audit.log | jq -r 'select(.objectRef.resource == "secrets" and .verb == "get") | 
  .user.username' | sort | uniq
```

### Bước 3: Tìm request bị từ chối 403

```bash
# Tìm tất cả request bị từ chối (responseStatus.code = 403)
cat /tmp/sample-audit.log | jq -r 'select(.responseStatus.code == 403) | 
  "\(.user.username) \(.verb) \(.objectRef.resource) - \(.responseStatus.reason)"'

# Đếm số lượng 403 theo user
cat /tmp/sample-audit.log | jq -r 'select(.responseStatus.code == 403) | .user.username' | 
  sort | uniq -c | sort -rn
```

### Bước 4: Tìm thao tác exec vào pod

```bash
# Tìm events exec vào pod
cat /tmp/sample-audit.log | jq -r 'select(.verb == "create" and 
  .objectRef.subresource == "exec") | 
  "\(.user.username) exec into \(.objectRef.name) in \(.objectRef.namespace)"'
```

### Bước 5: Ghi câu trả lời

```bash
cat > /tmp/answers.txt <<EOF
Q1: User đã truy cập Secret: <tên user>
Q2: Request bị từ chối 403: <tên user hoặc mô tả>
Q3: Exec vào pod: <tên pod>
EOF
```

### Bước 6: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] File `/tmp/answers.txt` tồn tại
- [ ] File `/tmp/answers.txt` chứa câu trả lời cho câu hỏi về Secret access
- [ ] File `/tmp/answers.txt` chứa câu trả lời cho câu hỏi về 403 và exec

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cấu trúc Kubernetes audit log event</summary>

Mỗi event trong audit log có cấu trúc JSON:
```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "RequestResponse",
  "auditID": "...",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/default/secrets/my-secret",
  "verb": "get",
  "user": {
    "username": "alice",
    "groups": ["system:authenticated"]
  },
  "objectRef": {
    "resource": "secrets",
    "namespace": "default",
    "name": "my-secret",
    "apiVersion": "v1"
  },
  "responseStatus": {
    "code": 200
  },
  "requestReceivedTimestamp": "2024-01-15T10:00:00Z"
}
```

</details>

<details>
<summary>Gợi ý 2: Các jq filter hữu ích</summary>

```bash
# Lọc theo resource
jq 'select(.objectRef.resource == "secrets")'

# Lọc theo verb
jq 'select(.verb == "get")'

# Lọc theo response code
jq 'select(.responseStatus.code == 403)'

# Lọc theo subresource (exec)
jq 'select(.objectRef.subresource == "exec")'

# Kết hợp nhiều điều kiện
jq 'select(.objectRef.resource == "secrets" and .verb == "get" and .responseStatus.code == 200)'

# Lấy nhiều field
jq -r '[.user.username, .verb, .objectRef.resource] | @tsv'
```

</details>

<details>
<summary>Gợi ý 3: Format file answers.txt</summary>

File `/tmp/answers.txt` cần chứa các từ khóa để verify script có thể kiểm tra:
- Câu trả lời Q1 phải chứa tên user đã truy cập secret (ví dụ: `alice`)
- Câu trả lời Q2 phải chứa thông tin về 403 (ví dụ: `bob` hoặc `403`)
- Câu trả lời Q3 phải chứa tên pod bị exec (ví dụ: `web-pod`)

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### Kubernetes Audit Log là gì?

Audit log ghi lại tất cả các request đến kube-apiserver, bao gồm:
- **Who**: User/ServiceAccount thực hiện request
- **What**: Verb (get, list, create, delete, v.v.) và resource
- **When**: Timestamp
- **Where**: Namespace và resource name
- **Result**: Response code (200, 403, 404, v.v.)

### Audit Levels

| Level | Ghi lại |
|-------|---------|
| `None` | Không ghi |
| `Metadata` | Chỉ metadata (user, verb, resource) |
| `Request` | Metadata + request body |
| `RequestResponse` | Metadata + request + response body |

### Cấu hình Audit Policy

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Ghi lại Secret ở mức RequestResponse
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
# Ghi lại các resource khác ở mức Metadata
- level: Metadata
  resources:
  - group: ""
    resources: ["pods", "services"]
```

### Phân tích audit log trong điều tra sự cố

Khi điều tra sự cố bảo mật, tìm kiếm:
1. **Privilege escalation**: User thường không có quyền đột nhiên thực hiện được action
2. **Secret access**: Ai đã đọc secret nào, khi nào
3. **Exec into pod**: Ai đã exec vào pod nào (dấu hiệu tấn công)
4. **Mass deletion**: Xóa nhiều resource trong thời gian ngắn
5. **Unusual hours**: Request vào giờ bất thường

---

## Tham khảo

- [Kubernetes Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [jq Manual](https://jqlang.github.io/jq/manual/)
- [CKS Exam – Monitoring, Logging and Runtime Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
