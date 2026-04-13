# Mock Exam 2 – CKS Practice Test (Troubleshooting Focus)

**Thời gian:** 2 giờ (120 phút)
**Tổng điểm:** 100 điểm
**Điểm đạt:** 67 điểm (67%)

---

## Hướng dẫn

1. Chạy `bash setup.sh` để khởi tạo môi trường trước khi bắt đầu
2. Bấm giờ 120 phút và hoàn thành tất cả câu hỏi
3. Sau khi hết giờ, xem đáp án tại `solutions/answers.md`
4. Bài thi này tập trung vào **troubleshooting** — tìm và sửa cấu hình bảo mật sai

## Phân bổ điểm theo domain

| Domain | Trọng số | Điểm | Câu hỏi |
|--------|----------|------|---------|
| Cluster Setup | 15% | 15 | Q1, Q2 |
| Cluster Hardening | 15% | 15 | Q3, Q4 |
| System Hardening | 10% | 10 | Q5, Q6 |
| Minimize Microservice Vulnerabilities | 20% | 20 | Q7, Q8, Q9 |
| Supply Chain Security | 20% | 20 | Q10, Q11, Q12 |
| Monitoring, Logging & Runtime Security | 20% | 20 | Q13, Q14, Q15 |

---

## Câu hỏi

### Q1 – Fix NetworkPolicy (8 điểm) [Cluster Setup]

Namespace `fix-backend` có NetworkPolicy `broken-policy` nhưng cấu hình sai — nó đang cho phép tất cả ingress thay vì chặn.

**Yêu cầu:**
- Sửa NetworkPolicy `broken-policy` trong namespace `fix-backend` để chặn toàn bộ ingress mặc định (podSelector rỗng, không có ingress rules)

**Kiểm tra:**
```bash
kubectl get networkpolicy broken-policy -n fix-backend -o jsonpath='{.spec.ingress}'
# Mong đợi: rỗng (không có ingress rules)
```

---

### Q2 – Fix PSS Label (7 điểm) [Cluster Setup]

Namespace `fix-pss` có label PSS nhưng đang dùng level `baseline` thay vì `restricted`.

**Yêu cầu:**
- Cập nhật namespace `fix-pss` để enforce PSS level `restricted` (version `latest`)

**Kiểm tra:**
```bash
kubectl get namespace fix-pss -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'
# Mong đợi: restricted
```

---

### Q3 – Fix RBAC Wildcard (8 điểm) [Cluster Hardening]

Role `broken-role` trong namespace `fix-rbac` đang dùng wildcard verb `*` — vi phạm least-privilege.

**Yêu cầu:**
- Sửa Role `broken-role` để chỉ cho phép verbs `get`, `list`, `watch` trên resource `pods`

**Kiểm tra:**
```bash
kubectl get role broken-role -n fix-rbac -o jsonpath='{.rules[0].verbs}'
# Mong đợi: ["get","list","watch"]
```

---

### Q4 – Fix Audit Policy (7 điểm) [Cluster Hardening]

File `/tmp/fix-audit-policy.yaml` có lỗi: Secret đang được log ở mức `Metadata` thay vì `RequestResponse`.

**Yêu cầu:**
- Sửa file `/tmp/fix-audit-policy.yaml` để Secret được log ở mức `RequestResponse`
- Lưu file đã sửa tại `/tmp/fixed-audit-policy.yaml`

**Kiểm tra:**
```bash
grep -A3 "secrets" /tmp/fixed-audit-policy.yaml | grep "level"
# Mong đợi: level: RequestResponse
```

---

### Q5 – Fix AppArmor Annotation (5 điểm) [System Hardening]

Pod `broken-apparmor` trong namespace `fix-system` có annotation AppArmor sai tên container.

**Yêu cầu:**
- Xóa và tạo lại pod `broken-apparmor` với annotation đúng cho container tên `app` (profile: `runtime/default`)

**Kiểm tra:**
```bash
kubectl get pod broken-apparmor -n fix-system \
  -o jsonpath='{.metadata.annotations.container\.apparmor\.security\.beta\.kubernetes\.io/app}'
# Mong đợi: runtime/default
```

---

### Q6 – Fix SecurityContext (5 điểm) [System Hardening]

Pod `insecure-pod` trong namespace `fix-system` đang chạy với `privileged: true` và `allowPrivilegeEscalation: true`.

**Yêu cầu:**
- Xóa và tạo lại pod `insecure-pod` với `privileged: false`, `allowPrivilegeEscalation: false`, `runAsNonRoot: true`, `capabilities.drop: [ALL]`

**Kiểm tra:**
```bash
kubectl get pod insecure-pod -n fix-system \
  -o jsonpath='{.spec.containers[0].securityContext}'
```

---

### Q7 – Fix Image Version (6 điểm) [Microservice Vulnerabilities]

Deployment `web-deploy` trong namespace `fix-micro` đang dùng image `nginx:1.14.0` có CRITICAL CVEs.

**Yêu cầu:**
- Cập nhật Deployment `web-deploy` để dùng image `nginx:1.25-alpine`

**Kiểm tra:**
```bash
kubectl get deployment web-deploy -n fix-micro \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Mong đợi: nginx:1.25-alpine
```

---

### Q8 – Fix Secret Mount (7 điểm) [Microservice Vulnerabilities]

Pod `bad-secret-pod` trong namespace `fix-micro` đang mount Secret `app-secret` qua environment variable.

**Yêu cầu:**
- Xóa pod `bad-secret-pod` và tạo lại với Secret được mount dưới dạng volume tại `/etc/app-secret` với `defaultMode: 0400`

**Kiểm tra:**
```bash
kubectl get pod bad-secret-pod -n fix-micro \
  -o jsonpath='{.spec.volumes[0].secret.defaultMode}'
# Mong đợi: 256 (= 0400 octal)
```

---

### Q9 – Fix EncryptionConfiguration (7 điểm) [Microservice Vulnerabilities]

File `/tmp/fix-encryption.yaml` có lỗi: provider `identity` được đặt trước `aescbc` — điều này có nghĩa Secret sẽ KHÔNG được mã hóa.

**Yêu cầu:**
- Sửa file `/tmp/fix-encryption.yaml` để `aescbc` là provider đầu tiên, `identity` là fallback
- Lưu tại `/tmp/fixed-encryption.yaml`

**Kiểm tra:**
```bash
python3 -c "
import yaml
with open('/tmp/fixed-encryption.yaml') as f:
    cfg = yaml.safe_load(f)
first = cfg['resources'][0]['providers'][0]
print('First provider:', list(first.keys())[0])
"
# Mong đợi: First provider: aescbc
```

---

### Q10 – Verify cosign Signature (7 điểm) [Supply Chain Security]

**Yêu cầu:**
- Tạo cosign key pair tại `/tmp/fix-cosign/`
- Ký image `nginx:1.25-alpine`
- Xác minh chữ ký thành công và ghi output vào `/tmp/fix-cosign/verify-output.txt`

**Kiểm tra:**
```bash
ls /tmp/fix-cosign/
cat /tmp/fix-cosign/verify-output.txt
```

---

### Q11 – Fix Insecure Dockerfile (6 điểm) [Supply Chain Security]

File `/tmp/fix-dockerfile` chứa Dockerfile có vấn đề: chạy với root user và dùng `latest` tag.

**Yêu cầu:**
- Tạo Dockerfile đã sửa tại `/tmp/fixed-dockerfile` với:
  - Dùng image tag cụ thể (không dùng `latest`)
  - Thêm non-root user và `USER` instruction
  - Dùng multi-stage build nếu có thể

**Kiểm tra:**
```bash
grep "USER" /tmp/fixed-dockerfile
grep -v "latest" /tmp/fixed-dockerfile | grep "FROM"
```

---

### Q12 – Fix Gatekeeper Constraint (7 điểm) [Supply Chain Security]

ConstraintTemplate `K8sFixAllowedRepos` đã tồn tại. Constraint `fix-allowed-repos` đang bị thiếu namespace selector.

**Yêu cầu:**
- Sửa Constraint `fix-allowed-repos` để áp dụng cho namespace `fix-policy`
- Allowed repos: `registry.k8s.io`, `docker.io/library`

**Kiểm tra:**
```bash
kubectl get k8sfixallowedrepos fix-allowed-repos \
  -o jsonpath='{.spec.match.namespaces}'
```

---

### Q13 – Fix Falco Rule (7 điểm) [Monitoring/Runtime]

File `/tmp/fix-falco-rule.yaml` chứa Falco rule có lỗi cú pháp — thiếu field `output`.

**Yêu cầu:**
- Sửa file `/tmp/fix-falco-rule.yaml` để thêm field `output` hợp lệ
- Lưu tại `/tmp/fixed-falco-rule.yaml`

**Kiểm tra:**
```bash
grep "output:" /tmp/fixed-falco-rule.yaml
```

---

### Q14 – Audit Log Forensics (6 điểm) [Monitoring/Runtime]

File `/tmp/fix-audit.log` chứa audit log của một sự cố bảo mật.

**Yêu cầu:**
Phân tích và ghi câu trả lời vào `/tmp/fix-audit-answers.txt`:
- Q14a: ServiceAccount nào đã tạo pod trong namespace `fix-audit`?
- Q14b: Lúc mấy giờ (timestamp) Secret `fix-secret` bị đọc lần đầu?
- Q14c: Có bao nhiêu lần exec vào pod trong log?

**Kiểm tra:**
```bash
cat /tmp/fix-audit-answers.txt
```

---

### Q15 – Fix Mutable Container (7 điểm) [Monitoring/Runtime]

Pod `mutable-pod` trong namespace `fix-runtime` không có `readOnlyRootFilesystem`.

**Yêu cầu:**
- Xóa pod `mutable-pod` và tạo lại với:
  - `readOnlyRootFilesystem: true`
  - emptyDir mounts tại `/tmp` và `/var/cache/nginx`
  - `runAsNonRoot: true`, `allowPrivilegeEscalation: false`

**Kiểm tra:**
```bash
kubectl get pod mutable-pod -n fix-runtime \
  -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'
# Mong đợi: true
```

---

## Sau khi hoàn thành

Xem đáp án chi tiết tại: `solutions/answers.md`

Dọn dẹp môi trường:
```bash
bash cleanup.sh
```
