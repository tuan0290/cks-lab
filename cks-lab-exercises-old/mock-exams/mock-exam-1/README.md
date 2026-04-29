# Mock Exam 1 – CKS Practice Test

**Thời gian:** 2 giờ (120 phút)
**Tổng điểm:** 100 điểm
**Điểm đạt:** 67 điểm (67%)

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

### Q1 – NetworkPolicy (8 điểm) [Cluster Setup]

Namespace `exam-frontend` và `exam-backend` đã được tạo sẵn.

**Yêu cầu:**
- Tạo NetworkPolicy `deny-all` trong namespace `exam-backend` chặn toàn bộ ingress và egress mặc định
- Tạo NetworkPolicy `allow-frontend` trong namespace `exam-backend` chỉ cho phép ingress từ namespace `exam-frontend` trên port 8080

**Kiểm tra:**
```bash
kubectl get networkpolicy -n exam-backend
```

---

### Q2 – Pod Security Standards (7 điểm) [Cluster Setup]

**Yêu cầu:**
- Gắn nhãn namespace `exam-restricted` với PSS level `restricted` (enforce mode, version latest)
- Xác minh pod `privileged-test` trong namespace `exam-restricted` bị từ chối

**Kiểm tra:**
```bash
kubectl get namespace exam-restricted --show-labels
```

---

### Q3 – RBAC Least Privilege (8 điểm) [Cluster Hardening]

ServiceAccount `exam-sa` trong namespace `exam-rbac` đang có ClusterRoleBinding `exam-sa-admin` gán quyền `cluster-admin`.

**Yêu cầu:**
- Xóa ClusterRoleBinding `exam-sa-admin`
- Tạo Role `secret-reader` trong namespace `exam-rbac` chỉ cho phép `get`, `list` secrets
- Tạo RoleBinding gắn Role đó với `exam-sa`

**Kiểm tra:**
```bash
kubectl auth can-i list secrets --as=system:serviceaccount:exam-rbac:exam-sa -n exam-rbac
kubectl auth can-i delete pods --as=system:serviceaccount:exam-rbac:exam-sa -n exam-rbac
```

---

### Q4 – ServiceAccount Token (7 điểm) [Cluster Hardening]

**Yêu cầu:**
- Vô hiệu hóa automount ServiceAccount token trên ServiceAccount `no-token-sa` trong namespace `exam-rbac`
- Xóa và tạo lại pod `no-token-pod` với `automountServiceAccountToken: false`

**Kiểm tra:**
```bash
kubectl exec no-token-pod -n exam-rbac -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
```

---

### Q5 – AppArmor (5 điểm) [System Hardening]

AppArmor profile `exam-deny-write` đã được load trên node.

**Yêu cầu:**
- Tạo pod `apparmor-pod` trong namespace `exam-system` với container `main` sử dụng AppArmor profile `exam-deny-write`

**Kiểm tra:**
```bash
kubectl get pod apparmor-pod -n exam-system -o jsonpath='{.metadata.annotations}'
```

---

### Q6 – Seccomp + SecurityContext (5 điểm) [System Hardening]

**Yêu cầu:**
- Tạo pod `hardened-pod` trong namespace `exam-system` với:
  - `seccompProfile.type: RuntimeDefault`
  - `runAsNonRoot: true`, `runAsUser: 1000`
  - `allowPrivilegeEscalation: false`
  - `readOnlyRootFilesystem: true`
  - `capabilities.drop: [ALL]`
  - emptyDir mount tại `/tmp`

**Kiểm tra:**
```bash
kubectl get pod hardened-pod -n exam-system -o jsonpath='{.spec.securityContext}'
```

---

### Q7 – Trivy Image Scan (6 điểm) [Microservice Vulnerabilities]

Pod `vulnerable-app` trong namespace `exam-micro` đang dùng image `nginx:1.14.0`.

**Yêu cầu:**
- Quét image `nginx:1.14.0` bằng trivy và ghi số lượng lỗ hổng CRITICAL vào file `/tmp/trivy-result.txt`
- Cập nhật pod để dùng image `nginx:1.25-alpine`

**Kiểm tra:**
```bash
kubectl get pod vulnerable-app -n exam-micro -o jsonpath='{.spec.containers[0].image}'
cat /tmp/trivy-result.txt
```

---

### Q8 – Secret Volume Mount (7 điểm) [Microservice Vulnerabilities]

Secret `exam-credentials` đã tồn tại trong namespace `exam-micro`.

**Yêu cầu:**
- Tạo pod `secure-mount` trong namespace `exam-micro` mount Secret `exam-credentials` dưới dạng volume tại `/etc/credentials` với `defaultMode: 0400`
- Không được dùng environment variable

**Kiểm tra:**
```bash
kubectl get pod secure-mount -n exam-micro -o jsonpath='{.spec.volumes}'
```

---

### Q9 – RuntimeClass (7 điểm) [Microservice Vulnerabilities]

**Yêu cầu:**
- Tạo RuntimeClass `exam-sandbox` với handler `runsc`
- Tạo pod `sandboxed-app` trong namespace `exam-micro` với `runtimeClassName: exam-sandbox`

**Kiểm tra:**
```bash
kubectl get runtimeclass exam-sandbox
kubectl get pod sandboxed-app -n exam-micro -o jsonpath='{.spec.runtimeClassName}'
```

---

### Q10 – cosign Image Signing (7 điểm) [Supply Chain Security]

**Yêu cầu:**
- Tạo cosign key pair tại `/tmp/exam-cosign/`
- Ký image `nginx:1.25-alpine` bằng private key
- Ghi lệnh verify vào file `/tmp/exam-cosign/verify-cmd.txt`

**Kiểm tra:**
```bash
ls /tmp/exam-cosign/
cat /tmp/exam-cosign/verify-cmd.txt
```

---

### Q11 – Static Analysis (6 điểm) [Supply Chain Security]

File `/tmp/exam-insecure.yaml` chứa manifest có vấn đề bảo mật.

**Yêu cầu:**
- Phân tích manifest bằng `kubesec scan` hoặc `trivy config`
- Tạo manifest đã sửa tại `/tmp/exam-fixed.yaml` không còn `privileged: true` và `hostPID: true`

**Kiểm tra:**
```bash
grep -c "privileged: true" /tmp/exam-fixed.yaml || echo "0 occurrences - PASS"
grep -c "hostPID: true" /tmp/exam-fixed.yaml || echo "0 occurrences - PASS"
```

---

### Q12 – Image Policy (7 điểm) [Supply Chain Security]

**Yêu cầu:**
- Tạo ConstraintTemplate `K8sExamAllowedRepos` và Constraint `exam-allowed-repos` chỉ cho phép image từ `registry.k8s.io` và `docker.io/library` trong namespace `exam-policy`

**Kiểm tra:**
```bash
kubectl get constrainttemplate k8sexamallowedrepos
kubectl get k8sexamallowedrepos exam-allowed-repos
```

---

### Q13 – Falco Rules (7 điểm) [Monitoring/Runtime]

**Yêu cầu:**
- Tạo custom Falco rule file tại `/etc/falco/rules.d/exam-rules.yaml` phát hiện khi process `curl` hoặc `wget` chạy trong container
- Rule phải có priority `WARNING` và tag `[network, container]`

**Kiểm tra:**
```bash
cat /etc/falco/rules.d/exam-rules.yaml
```

---

### Q14 – Audit Log Analysis (6 điểm) [Monitoring/Runtime]

File audit log `/tmp/exam-audit.log` đã được tạo sẵn.

**Yêu cầu:**
Phân tích audit log và ghi câu trả lời vào `/tmp/exam-audit-answers.txt`:
- Q14a: User nào đã xóa Secret `exam-secret` trong namespace `exam-audit`?
- Q14b: Có bao nhiêu request bị từ chối (403) trong log?
- Q14c: User nào đã exec vào pod?

**Kiểm tra:**
```bash
cat /tmp/exam-audit-answers.txt
```

---

### Q15 – Immutable Container (7 điểm) [Monitoring/Runtime]

**Yêu cầu:**
- Tạo pod `immutable-exam` trong namespace `exam-runtime` với:
  - `readOnlyRootFilesystem: true`
  - emptyDir mounts tại `/tmp` và `/var/run`
  - `runAsNonRoot: true`, `allowPrivilegeEscalation: false`

**Kiểm tra:**
```bash
kubectl get pod immutable-exam -n exam-runtime -o jsonpath='{.spec.containers[0].securityContext}'
kubectl exec immutable-exam -n exam-runtime -- touch /etc/test 2>&1 || echo "PASS: read-only filesystem"
```

---

## Sau khi hoàn thành

Xem đáp án chi tiết tại: `solutions/answers.md`

Dọn dẹp môi trường:
```bash
bash cleanup.sh
```
