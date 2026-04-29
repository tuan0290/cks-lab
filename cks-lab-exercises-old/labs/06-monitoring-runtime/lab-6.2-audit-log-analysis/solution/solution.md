# Giải pháp – Lab 6.2 Audit Log Analysis

## Bước 1: Xem cấu trúc audit log

```bash
# Xem một event
cat /tmp/sample-audit.log | head -1 | jq .

# Đếm tổng số events
wc -l /tmp/sample-audit.log
```

Output: 10 events

## Câu hỏi 1: User nào đã truy cập Secret?

```bash
# Tìm tất cả events liên quan đến Secret
cat /tmp/sample-audit.log | jq -r 'select(.objectRef.resource == "secrets") | 
  "\(.user.username) \(.verb) secret/\(.objectRef.name) in \(.objectRef.namespace) -> \(.responseStatus.code)"'
```

Output:
```
alice get secret/db-password in production -> 200
bob list secret/ in production -> 403
alice get secret/api-key in production -> 200
alice get secret/admin-token in kube-system -> 200
```

**Câu trả lời Q1: `alice` đã truy cập Secret (3 lần: db-password, api-key, admin-token)**

```bash
# Lấy danh sách user đã GET secret thành công
cat /tmp/sample-audit.log | jq -r 'select(.objectRef.resource == "secrets" and .responseStatus.code == 200) | 
  .user.username' | sort | uniq
```

Output: `alice`

## Câu hỏi 2: Request nào bị từ chối 403?

```bash
# Tìm tất cả request bị từ chối
cat /tmp/sample-audit.log | jq -r 'select(.responseStatus.code == 403) | 
  "\(.user.username) \(.verb) \(.objectRef.resource) -> \(.responseStatus.message)"'
```

Output:
```
bob list secrets -> bob cannot list secrets in namespace production
bob create deployments -> bob cannot create deployments in namespace production
bob create clusterrolebindings -> bob cannot create clusterrolebindings
```

**Câu trả lời Q2: User `bob` có 3 request bị từ chối 403:**
- Không thể list secrets trong namespace production
- Không thể create deployments trong namespace production
- Không thể create clusterrolebindings

```bash
# Đếm số 403 theo user
cat /tmp/sample-audit.log | jq -r 'select(.responseStatus.code == 403) | .user.username' | 
  sort | uniq -c | sort -rn
```

Output: `3 bob`

## Câu hỏi 3: Ai đã exec vào pod nào?

```bash
# Tìm tất cả thao tác exec
cat /tmp/sample-audit.log | jq -r 'select(.objectRef.subresource == "exec") | 
  "\(.user.username) exec into pod/\(.objectRef.name) in \(.objectRef.namespace) at \(.requestReceivedTimestamp)"'
```

Output:
```
charlie exec into pod/web-pod in production at 2024-01-15T08:35:00Z
charlie exec into pod/db-pod in production at 2024-01-15T08:40:00Z
```

**Câu trả lời Q3: User `charlie` đã exec vào 2 pods: `web-pod` và `db-pod` trong namespace `production`**

## Bước 2: Ghi câu trả lời vào /tmp/answers.txt

```bash
cat > /tmp/answers.txt <<EOF
Q1: User đã truy cập Secret: alice
    - alice GET secret/db-password in production (200)
    - alice GET secret/api-key in production (200)
    - alice GET secret/admin-token in kube-system (200)

Q2: Request bị từ chối 403: bob
    - bob list secrets in production (403 Forbidden)
    - bob create deployments in production (403 Forbidden)
    - bob create clusterrolebindings (403 Forbidden)

Q3: Exec vào pod: charlie exec vào web-pod và db-pod
    - charlie exec into web-pod in production at 2024-01-15T08:35:00Z
    - charlie exec into db-pod in production at 2024-01-15T08:40:00Z
EOF
```

## Bước 3: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] File /tmp/answers.txt tồn tại
[PASS] File /tmp/answers.txt chứa câu trả lời đúng về user truy cập Secret (alice)
[PASS] File /tmp/answers.txt chứa câu trả lời về request 403 (bob) và exec vào pod (charlie)
---
Kết quả: 3/3 tiêu chí đạt
```

## Tóm tắt jq commands cho audit log analysis

```bash
# Tìm tất cả events theo resource
jq 'select(.objectRef.resource == "secrets")' /tmp/sample-audit.log

# Tìm events theo user
jq 'select(.user.username == "alice")' /tmp/sample-audit.log

# Tìm events bị từ chối
jq 'select(.responseStatus.code == 403)' /tmp/sample-audit.log

# Tìm exec events
jq 'select(.objectRef.subresource == "exec")' /tmp/sample-audit.log

# Tìm events trong khoảng thời gian
jq 'select(.requestReceivedTimestamp >= "2024-01-15T08:30:00Z" and 
           .requestReceivedTimestamp <= "2024-01-15T08:40:00Z")' /tmp/sample-audit.log

# Tổng hợp theo user và verb
jq -r '[.user.username, .verb, .objectRef.resource, (.responseStatus.code | tostring)] | @tsv' \
  /tmp/sample-audit.log | sort | uniq -c | sort -rn

# Tìm events xóa resource
jq 'select(.verb == "delete")' /tmp/sample-audit.log

# Tìm events tạo ClusterRoleBinding (privilege escalation)
jq 'select(.objectRef.resource == "clusterrolebindings" and .verb == "create")' /tmp/sample-audit.log
```

## Phân tích bảo mật từ audit log

Từ kết quả phân tích, có thể nhận thấy:

1. **alice** có quyền đọc Secret trong nhiều namespace (kể cả kube-system) — đây là dấu hiệu đáng lo ngại vì developer không nên đọc được secret trong kube-system

2. **bob** đang cố gắng leo thang đặc quyền (privilege escalation):
   - Cố tạo ClusterRoleBinding (để tự cấp quyền cho mình)
   - Cố tạo Deployment và list Secret mà không có quyền

3. **charlie** đã exec vào 2 pods quan trọng (web-pod và db-pod) — cần điều tra xem charlie có quyền hợp lệ không và đã làm gì trong các pods đó

### Hành động khuyến nghị

- Revoke quyền của alice đọc secret trong kube-system
- Điều tra hành vi của bob — có thể là tấn công privilege escalation
- Kiểm tra audit log chi tiết hơn về các lệnh charlie đã chạy trong pods
