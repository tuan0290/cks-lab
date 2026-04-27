# Mock Exam 3 – CKS Practice Test (Advanced)

**Thời gian:** 2 giờ (120 phút)
**Tổng điểm:** 100 điểm
**Điểm đạt:** 67 điểm (67%)
**Chủ đề:** Tập trung vào các kỹ năng nâng cao và tình huống thực tế

---

## Hướng dẫn

1. Chạy `bash setup.sh` để khởi tạo môi trường trước khi bắt đầu
2. Bấm giờ 120 phút và hoàn thành tất cả câu hỏi
3. Sau khi hết giờ, xem đáp án tại `solutions/answers.md`
4. Tính điểm theo bảng phân bổ bên dưới

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

### Q1 – NetworkPolicy Egress Control (8 điểm) [Cluster Setup]

Namespace `m3-app` đã được tạo sẵn với pod `backend` đang chạy.

**Yêu cầu:**
- Tạo NetworkPolicy `restrict-egress` trong namespace `m3-app`:
  - Chặn toàn bộ egress mặc định
  - Chỉ cho phép egress đến namespace `m3-db` trên port `5432`
  - Chỉ cho phép egress DNS (port `53` UDP/TCP) đến bất kỳ đâu

**Kiểm tra:**
```bash
kubectl get networkpolicy restrict-egress -n m3-app -o yaml
```

---

### Q2 – kube-bench CIS Remediation (7 điểm) [Cluster Setup]

File `/tmp/m3-kubebench-output.txt` chứa output của kube-bench với 2 FAIL cần sửa.

**Yêu cầu:**
- Đọc file và xác định 2 vấn đề cần sửa
- Sửa kubelet config tại `/var/lib/kubelet/config.yaml`:
  - Đặt `readOnlyPort: 0`
  - Đặt `authentication.anonymous.enabled: false`
- Lưu các thay đổi và restart kubelet

**Kiểm tra:**
```bash
grep "readOnlyPort" /var/lib/kubelet/config.yaml
grep -A2 "anonymous:" /var/lib/kubelet/config.yaml
```

---

### Q3 – Audit Policy Advanced (8 điểm) [Cluster Hardening]

**Yêu cầu:**
Tạo audit policy tại `/etc/kubernetes/audit/policy.yaml` với các rule sau (theo đúng thứ tự):
1. Không log gì từ `system:nodes` group
2. Log `RequestResponse` cho mọi thao tác `create/update/delete/patch` trên `secrets`
3. Log `Request` cho mọi thao tác `get/list` trên `secrets`
4. Log `RequestResponse` cho `create/delete` trên `pods` trong namespace `m3-prod`
5. Log `Metadata` cho tất cả còn lại (bỏ qua stage `RequestReceived`)

Thêm vào kube-apiserver:
```
--audit-log-path=/var/log/kubernetes/audit/audit.log
--audit-policy-file=/etc/kubernetes/audit/policy.yaml
--audit-log-maxage=7
--audit-log-maxbackup=3
--audit-log-maxsize=50
```

**Kiểm tra:**
```bash
cat /etc/kubernetes/audit/policy.yaml
grep "audit-log-path" /etc/kubernetes/manifests/kube-apiserver.yaml
```

---

### Q4 – ServiceAccount Hardening (7 điểm) [Cluster Hardening]

Namespace `m3-secure` đã được tạo sẵn.

**Yêu cầu:**
- Tạo ServiceAccount `app-sa` trong namespace `m3-secure` với `automountServiceAccountToken: false`
- Tạo Role `pod-reader` chỉ cho phép `get`, `list`, `watch` trên `pods` và `pods/log`
- Tạo RoleBinding gắn `pod-reader` với `app-sa`
- Tạo pod `app-pod` dùng `app-sa`, với `automountServiceAccountToken: false` ở cả pod level

**Kiểm tra:**
```bash
kubectl auth can-i get pods --as=system:serviceaccount:m3-secure:app-sa -n m3-secure
kubectl auth can-i delete pods --as=system:serviceaccount:m3-secure:app-sa -n m3-secure
kubectl exec app-pod -n m3-secure -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1 || echo "No token mounted"
```

---

### Q5 – seccomp Custom Profile (5 điểm) [System Hardening]

**Yêu cầu:**
- Tạo seccomp profile tại `/var/lib/kubelet/seccomp/m3-profile.json` với:
  - `defaultAction: SCMP_ACT_ERRNO`
  - Cho phép các syscall: `read`, `write`, `exit`, `exit_group`, `open`, `close`, `stat`, `fstat`, `mmap`, `mprotect`, `munmap`, `brk`, `rt_sigaction`, `rt_sigreturn`, `ioctl`, `access`, `execve`, `getpid`, `clone`, `wait4`, `nanosleep`, `socket`, `connect`, `sendto`, `recvfrom`, `bind`, `listen`, `accept`, `getsockname`, `setsockopt`, `getsockopt`, `fcntl`, `getdents64`, `lseek`, `pread64`, `pwrite64`
- Tạo pod `seccomp-pod` trong namespace `m3-system` dùng profile `m3-profile.json`

**Kiểm tra:**
```bash
kubectl get pod seccomp-pod -n m3-system \
  -o jsonpath='{.spec.securityContext.seccompProfile}'
```

---

### Q6 – AppArmor + Capabilities (5 điểm) [System Hardening]

**Yêu cầu:**
- Tạo pod `hardened-nginx` trong namespace `m3-system` với:
  - AppArmor profile `runtime/default`
  - `capabilities.drop: [ALL]`
  - `capabilities.add: [NET_BIND_SERVICE]`
  - `allowPrivilegeEscalation: false`
  - `runAsNonRoot: true`, `runAsUser: 101` (nginx user)
  - `readOnlyRootFilesystem: true`
  - emptyDir mounts tại `/var/cache/nginx`, `/var/run`, `/tmp`

**Kiểm tra:**
```bash
kubectl get pod hardened-nginx -n m3-system \
  -o jsonpath='{.spec.containers[0].securityContext}'
```

---

### Q7 – Trivy + Fix Deployment (6 điểm) [Microservice Vulnerabilities]

Deployment `web-app` trong namespace `m3-vuln` đang dùng image `nginx:1.14.0`.

**Yêu cầu:**
- Quét image `nginx:1.14.0` bằng trivy, lưu kết quả JSON vào `/tmp/m3-scan.json`
- Đếm số lỗ hổng CRITICAL và ghi vào `/tmp/m3-critical-count.txt`
- Cập nhật Deployment `web-app` sang image `nginx:1.25-alpine`
- Xác minh Deployment rollout thành công

**Kiểm tra:**
```bash
cat /tmp/m3-critical-count.txt
kubectl get deployment web-app -n m3-vuln \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

### Q8 – etcd Encryption (7 điểm) [Microservice Vulnerabilities]

**Yêu cầu:**
- Tạo EncryptionConfiguration tại `/etc/kubernetes/encryption/config.yaml`:
  - Mã hóa `secrets` bằng `aescbc` với key tự tạo (32 bytes base64)
  - `identity` là fallback provider
- Thêm vào kube-apiserver: `--encryption-provider-config=/etc/kubernetes/encryption/config.yaml`
- Tạo secret `m3-encrypted-secret` trong namespace `m3-secure` và xác minh nó được lưu mã hóa trong etcd

**Kiểm tra:**
```bash
grep "encryption-provider-config" /etc/kubernetes/manifests/kube-apiserver.yaml
kubectl get secret m3-encrypted-secret -n m3-secure
```

---

### Q9 – Pod Security Admission Strict (7 điểm) [Microservice Vulnerabilities]

**Yêu cầu:**
- Gắn nhãn namespace `m3-prod` với PSS `restricted` (enforce + audit + warn, version latest)
- Tạo pod `compliant-pod` trong namespace `m3-prod` đáp ứng đầy đủ `restricted` level:
  - `runAsNonRoot: true`, `runAsUser: 1000`
  - `seccompProfile.type: RuntimeDefault`
  - `allowPrivilegeEscalation: false`
  - `capabilities.drop: [ALL]`
  - `readOnlyRootFilesystem: true`
  - emptyDir tại `/tmp`
- Xác minh pod `violating-pod` (privileged) bị từ chối

**Kiểm tra:**
```bash
kubectl get pod compliant-pod -n m3-prod
kubectl run violating-pod --image=nginx --privileged -n m3-prod 2>&1 | grep -i "forbidden\|violat"
```

---

### Q10 – ImagePolicyWebhook (7 điểm) [Supply Chain Security]

File `/etc/kubernetes/policywebhook/admission_config.json` đã tồn tại nhưng chưa hoàn chỉnh.

**Yêu cầu:**
- Sửa `admission_config.json`:
  - `allowTTL: 100`
  - `denyTTL: 50`
  - `defaultAllow: false`
- Đảm bảo `kubeconf` trỏ đến `https://localhost:1234`
- Thêm vào kube-apiserver:
  - `--enable-admission-plugins=NodeRestriction,ImagePolicyWebhook`
  - `--admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json`
- Xác minh tạo pod bị từ chối (external service chưa tồn tại)

**Kiểm tra:**
```bash
kubectl run test-pod --image=nginx --restart=Never 2>&1 | grep -i "forbidden\|refused"
```

---

### Q11 – Cosign Sign + Verify (6 điểm) [Supply Chain Security]

**Yêu cầu:**
- Tạo cosign key pair tại `/tmp/m3-cosign/`
- Ký image `docker.io/library/nginx:1.25-alpine` bằng private key
- Xác minh chữ ký và lưu output vào `/tmp/m3-cosign/verify-output.txt`
- Tạo file `/tmp/m3-cosign/sign-policy.txt` mô tả tại sao cần ký image

**Kiểm tra:**
```bash
ls /tmp/m3-cosign/
cosign verify --key /tmp/m3-cosign/cosign.pub docker.io/library/nginx:1.25-alpine 2>/dev/null && echo "PASS"
```

---

### Q12 – Trivy Config Scan (7 điểm) [Supply Chain Security]

File `/tmp/m3-deployment.yaml` chứa Deployment manifest có nhiều vấn đề bảo mật.

**Yêu cầu:**
- Quét manifest bằng `trivy config /tmp/m3-deployment.yaml`
- Ghi danh sách các vấn đề tìm thấy vào `/tmp/m3-config-issues.txt`
- Tạo manifest đã sửa tại `/tmp/m3-deployment-fixed.yaml` khắc phục tất cả vấn đề HIGH/CRITICAL:
  - Thêm `readOnlyRootFilesystem: true`
  - Thêm `allowPrivilegeEscalation: false`
  - Thêm `runAsNonRoot: true`
  - Xóa `privileged: true`
  - Thêm `capabilities.drop: [ALL]`

**Kiểm tra:**
```bash
trivy config /tmp/m3-deployment-fixed.yaml 2>/dev/null | grep -c "HIGH\|CRITICAL" || echo "0 issues"
```

---

### Q13 – Falco Custom Rules (7 điểm) [Monitoring/Runtime]

**Yêu cầu:**
Tạo file `/etc/falco/rules.d/m3-rules.yaml` với 3 rules:

**Rule 1** – `Detect Package Manager in Container`:
- Phát hiện khi `apt`, `apt-get`, `yum`, `dnf`, `apk` chạy trong container
- Priority: `WARNING`, tags: `[container, package-manager]`

**Rule 2** – `Detect Write to /etc in Container`:
- Phát hiện khi có write vào `/etc/` trong container (trừ các process hợp lệ)
- Priority: `ERROR`, tags: `[container, filesystem]`

**Rule 3** – `Detect Outbound Connection to Suspicious Port`:
- Phát hiện khi container kết nối ra ngoài trên port `4444`, `1234`, `9001` (port thường dùng bởi reverse shell)
- Priority: `CRITICAL`, tags: `[network, container]`

**Kiểm tra:**
```bash
cat /etc/falco/rules.d/m3-rules.yaml
grep -c "rule:" /etc/falco/rules.d/m3-rules.yaml
# Mong đợi: 3
```

---

### Q14 – Audit Log Investigation (6 điểm) [Monitoring/Runtime]

File `/tmp/m3-audit.log` chứa audit log của một sự cố bảo mật nghiêm trọng.

**Yêu cầu:**
Phân tích audit log và ghi câu trả lời vào `/tmp/m3-audit-answers.txt`:
- Q14a: User nào đã tạo ClusterRoleBinding trong log?
- Q14b: ServiceAccount nào đã list secrets ở namespace `m3-prod`?
- Q14c: Có bao nhiêu lần anonymous user cố truy cập API?
- Q14d: Pod nào bị xóa và bởi user nào?

**Kiểm tra:**
```bash
cat /tmp/m3-audit-answers.txt
```

---

### Q15 – Runtime Threat Response (7 điểm) [Monitoring/Runtime]

Pod `suspicious-pod` trong namespace `m3-runtime` đang chạy với nhiều vấn đề bảo mật.

**Yêu cầu:**
- Kiểm tra pod `suspicious-pod` và xác định các vấn đề bảo mật
- Ghi danh sách vấn đề vào `/tmp/m3-threat-report.txt`
- Xóa pod `suspicious-pod`
- Tạo pod `secure-replacement` trong namespace `m3-runtime` thay thế với đầy đủ security hardening:
  - `readOnlyRootFilesystem: true`
  - `runAsNonRoot: true`, `runAsUser: 1000`
  - `allowPrivilegeEscalation: false`
  - `capabilities.drop: [ALL]`
  - `seccompProfile.type: RuntimeDefault`
  - emptyDir tại `/tmp`

**Kiểm tra:**
```bash
cat /tmp/m3-threat-report.txt
kubectl get pod suspicious-pod -n m3-runtime 2>&1 | grep "not found"
kubectl get pod secure-replacement -n m3-runtime
```

---

## Sau khi hoàn thành

Xem đáp án chi tiết tại: `solutions/answers.md`

Dọn dẹp môi trường:
```bash
bash cleanup.sh
```
