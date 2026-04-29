# Mock Exam 3 – CKS Practice Test (Full Coverage)

**Thời gian:** 3 giờ (180 phút)
**Tổng điểm:** 100 điểm
**Điểm đạt:** 67 điểm (67%)
**Chủ đề:** Bao phủ toàn bộ kiến thức trong CKS_2026_Lab_Guide.md

---

## Hướng dẫn

1. Chạy `bash setup.sh` để khởi tạo môi trường trước khi bắt đầu
2. Bấm giờ 180 phút và hoàn thành tất cả câu hỏi
3. Sau khi hết giờ, xem đáp án tại `solutions/answers.md`
4. Tính điểm theo bảng phân bổ bên dưới

## Phân bổ điểm theo domain

| Domain | Trọng số | Điểm | Câu hỏi |
|--------|----------|------|---------|
| Cluster Setup (15%) | 15% | 15 | Q1, Q2, Q3 |
| Cluster Hardening (15%) | 15% | 15 | Q4, Q5, Q6 |
| System Hardening (10%) | 10% | 10 | Q7, Q8, Q9 |
| Minimize Microservice Vulnerabilities (20%) | 20% | 20 | Q10, Q11, Q12, Q13 |
| Supply Chain Security (20%) | 20% | 20 | Q14, Q15, Q16, Q17 |
| Monitoring, Logging & Runtime Security (20%) | 20% | 20 | Q18, Q19, Q20, Q21 |

---

## Câu hỏi

### Q1 – NetworkPolicy Ingress (5 điểm) [Cluster Setup]

Namespace `m3-frontend` và `m3-backend` đã được tạo sẵn.

**Yêu cầu:**
- Tạo NetworkPolicy `deny-all` trong namespace `m3-backend` chặn toàn bộ ingress và egress mặc định
- Tạo NetworkPolicy `allow-frontend` trong namespace `m3-backend` chỉ cho phép ingress từ namespace `m3-frontend` trên port `8080`

**Kiểm tra:**
```bash
kubectl get networkpolicy -n m3-backend
```

---

### Q2 – NetworkPolicy Egress Control (5 điểm) [Cluster Setup]

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

### Q3 – containerd + kube-bench CIS (5 điểm) [Cluster Setup]

File `/tmp/m3-kubebench-output.txt` chứa output kube-bench với 2 FAIL.

**Yêu cầu:**
- Sửa kubelet config tại `/var/lib/kubelet/config.yaml`:
  - Đặt `readOnlyPort: 0`
  - Đặt `authentication.anonymous.enabled: false`
- Xác minh file `/etc/containerd/config.toml` có `SystemdCgroup = true`
- Restart kubelet

**Kiểm tra:**
```bash
grep "readOnlyPort" /var/lib/kubelet/config.yaml
grep "SystemdCgroup" /etc/containerd/config.toml
```

---

### Q4 – API Server Security Flags (5 điểm) [Cluster Hardening]

**Yêu cầu:**
Kiểm tra file `/etc/kubernetes/manifests/kube-apiserver.yaml` và đảm bảo các flag sau được cấu hình đúng:
- `--anonymous-auth=false`
- `--authorization-mode=Node,RBAC`
- `--enable-admission-plugins=NodeRestriction,EventRateLimit`
- `--service-account-lookup=true`

Ghi trạng thái hiện tại của từng flag vào `/tmp/m3-apiserver-audit.txt` (có/không có, giá trị hiện tại).

**Kiểm tra:**
```bash
cat /tmp/m3-apiserver-audit.txt
```

---

### Q5 – Audit Policy Advanced (5 điểm) [Cluster Hardening]

**Yêu cầu:**
Tạo audit policy tại `/etc/kubernetes/audit/policy.yaml` với các rule theo đúng thứ tự:
1. Không log gì từ `system:nodes` group
2. Log `RequestResponse` cho `create/update/delete/patch` trên `secrets`
3. Log `Request` cho `get/list` trên `secrets`
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

### Q6 – ServiceAccount + RBAC Hardening (5 điểm) [Cluster Hardening]

**Yêu cầu:**
- Tạo ServiceAccount `app-sa` trong namespace `m3-secure` với `automountServiceAccountToken: false`
- Tạo Role `pod-reader` chỉ cho phép `get`, `list`, `watch` trên `pods` và `pods/log`
- Tạo RoleBinding gắn `pod-reader` với `app-sa`
- Tạo pod `app-pod` dùng `app-sa` với `automountServiceAccountToken: false`

**Kiểm tra:**
```bash
kubectl auth can-i get pods --as=system:serviceaccount:m3-secure:app-sa -n m3-secure
kubectl auth can-i delete pods --as=system:serviceaccount:m3-secure:app-sa -n m3-secure
```

---

### Q7 – seccomp Custom Profile (4 điểm) [System Hardening]

**Yêu cầu:**
- Tạo seccomp profile tại `/var/lib/kubelet/seccomp/m3-profile.json` với `defaultAction: SCMP_ACT_ERRNO` và danh sách syscall được phép
- Tạo pod `seccomp-pod` trong namespace `m3-system` dùng profile `m3-profile.json` (type: Localhost)
- Tạo pod `seccomp-default-pod` trong namespace `m3-system` dùng `RuntimeDefault`

**Kiểm tra:**
```bash
kubectl get pod seccomp-pod -n m3-system -o jsonpath='{.spec.securityContext.seccompProfile}'
kubectl get pod seccomp-default-pod -n m3-system -o jsonpath='{.spec.securityContext.seccompProfile}'
```

---

### Q8 – AppArmor + Capabilities (3 điểm) [System Hardening]

**Yêu cầu:**
- Tạo pod `hardened-nginx` trong namespace `m3-system` với:
  - AppArmor profile `runtime/default`
  - `capabilities.drop: [ALL]`, `capabilities.add: [NET_BIND_SERVICE]`
  - `allowPrivilegeEscalation: false`, `runAsNonRoot: true`, `runAsUser: 101`
  - `readOnlyRootFilesystem: true`
  - emptyDir mounts tại `/var/cache/nginx`, `/var/run`, `/tmp`

**Kiểm tra:**
```bash
kubectl get pod hardened-nginx -n m3-system -o jsonpath='{.spec.containers[0].securityContext}'
```

---

### Q9 – Kernel Security Parameters (3 điểm) [System Hardening]

**Yêu cầu:**
- Tạo file `/etc/sysctl.d/99-m3-security.conf` với các tham số:
  - `net.ipv4.conf.all.send_redirects=0`
  - `net.ipv4.conf.all.accept_redirects=0`
  - `kernel.kexec_load_disabled=1`
  - `kernel.yama.ptrace_scope=1`
  - `fs.protected_hardlinks=1`
  - `fs.protected_symlinks=1`
- Áp dụng: `sysctl -p /etc/sysctl.d/99-m3-security.conf`

**Kiểm tra:**
```bash
sysctl kernel.kexec_load_disabled
sysctl fs.protected_hardlinks
```

---

### Q10 – Pod Security Admission Strict (5 điểm) [Microservice Vulnerabilities]

**Yêu cầu:**
- Gắn nhãn namespace `m3-prod` với PSS `restricted` (enforce + audit + warn, version latest)
- Tạo pod `compliant-pod` đáp ứng đầy đủ `restricted` level:
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

### Q11 – Trivy Image Scan (5 điểm) [Microservice Vulnerabilities]

Deployment `web-app` trong namespace `m3-vuln` đang dùng image `nginx:1.14.0`.

**Yêu cầu:**
- Quét image `nginx:1.14.0` bằng trivy, lưu kết quả JSON vào `/tmp/m3-scan.json`
- Đếm số lỗ hổng CRITICAL và ghi vào `/tmp/m3-critical-count.txt`
- Cập nhật Deployment `web-app` sang image `nginx:1.25-alpine`
- Xác minh rollout thành công

**Kiểm tra:**
```bash
cat /tmp/m3-critical-count.txt
kubectl get deployment web-app -n m3-vuln -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

### Q12 – etcd Encryption (5 điểm) [Microservice Vulnerabilities]

**Yêu cầu:**
- Tạo EncryptionConfiguration tại `/etc/kubernetes/encryption/config.yaml`:
  - Mã hóa `secrets` bằng `aescbc` với key 32 bytes base64
  - `identity` là fallback provider
- Thêm `--encryption-provider-config=/etc/kubernetes/encryption/config.yaml` vào kube-apiserver
- Tạo secret `m3-encrypted-secret` trong namespace `m3-secure`

**Kiểm tra:**
```bash
grep "encryption-provider-config" /etc/kubernetes/manifests/kube-apiserver.yaml
kubectl get secret m3-encrypted-secret -n m3-secure
```

---

### Q13 – ResourceQuota + LimitRange (5 điểm) [Microservice Vulnerabilities]

**Yêu cầu:**
Tạo trong namespace `m3-prod`:
- ResourceQuota `m3-quota`: `requests.cpu=2`, `requests.memory=4Gi`, `limits.cpu=4`, `limits.memory=8Gi`
- LimitRange `m3-limits` với default limit `cpu=500m, memory=512Mi`, default request `cpu=100m, memory=128Mi`

**Kiểm tra:**
```bash
kubectl get resourcequota m3-quota -n m3-prod
kubectl get limitrange m3-limits -n m3-prod
```

---

### Q14 – ImagePolicyWebhook (5 điểm) [Supply Chain Security]

File `/etc/kubernetes/policywebhook/admission_config.json` đã tồn tại nhưng chưa hoàn chỉnh.

**Yêu cầu:**
- Sửa `admission_config.json`: `allowTTL=100`, `denyTTL=50`, `defaultAllow=false`
- Đảm bảo `kubeconf` trỏ đến `https://localhost:1234`
- Thêm vào kube-apiserver: `--enable-admission-plugins=NodeRestriction,ImagePolicyWebhook` và `--admission-control-config-file`
- Xác minh tạo pod bị từ chối

**Kiểm tra:**
```bash
kubectl run test-pod --image=nginx --restart=Never 2>&1 | grep -i "forbidden\|refused"
```

---

### Q15 – Cosign Sign + Verify (5 điểm) [Supply Chain Security]

**Yêu cầu:**
- Tạo cosign key pair tại `/tmp/m3-cosign/`
- Ký image `docker.io/library/nginx:1.25-alpine`
- Xác minh chữ ký và lưu output vào `/tmp/m3-cosign/verify-output.txt`

**Kiểm tra:**
```bash
cosign verify --key /tmp/m3-cosign/cosign.pub docker.io/library/nginx:1.25-alpine 2>/dev/null && echo "PASS"
```

---

### Q16 – Kyverno Policy (5 điểm) [Supply Chain Security]

**Yêu cầu:**
Tạo Kyverno ClusterPolicy `check-image-registry` enforce chỉ cho phép image từ `registry.k8s.io` hoặc `docker.io/library` trong namespace `m3-prod`:
- `validationFailureAction: enforce`
- Match: kind `Pod`
- Pattern: image phải bắt đầu bằng `registry.k8s.io/*` hoặc `docker.io/library/*`

**Kiểm tra:**
```bash
kubectl get clusterpolicy check-image-registry
kubectl run bad-pod --image=gcr.io/google-containers/pause:3.1 -n m3-prod 2>&1 | grep -i "forbidden\|block"
```

---

### Q17 – SBOM với Syft + Trivy Config Scan (5 điểm) [Supply Chain Security]

**Yêu cầu:**
- Tạo SBOM cho image `nginx:1.25-alpine` bằng syft, lưu dạng `cyclonedx-json` vào `/tmp/m3-sbom.json`
- Tìm package `openssl` trong SBOM và ghi version vào `/tmp/m3-openssl-version.txt`
- Quét manifest `/tmp/m3-deployment.yaml` bằng `trivy config`, lưu issues vào `/tmp/m3-config-issues.txt`
- Tạo manifest đã sửa tại `/tmp/m3-deployment-fixed.yaml`

**Kiểm tra:**
```bash
cat /tmp/m3-openssl-version.txt
cat /tmp/m3-config-issues.txt
```

---

### Q18 – Falco Custom Rules (5 điểm) [Monitoring/Runtime]

**Yêu cầu:**
Tạo file `/etc/falco/rules.d/m3-rules.yaml` với 3 rules:

**Rule 1** – `Detect Package Manager in Container`: phát hiện `apt`, `apt-get`, `yum`, `dnf`, `apk` trong container. Priority: `WARNING`, tags: `[container, package-manager]`

**Rule 2** – `Detect Write to /etc in Container`: phát hiện write vào `/etc/` trong container. Priority: `ERROR`, tags: `[container, filesystem]`

**Rule 3** – `Detect Outbound Connection to Suspicious Port`: phát hiện kết nối ra port `4444`, `1234`, `9001`. Priority: `CRITICAL`, tags: `[network, container]`

**Kiểm tra:**
```bash
grep -c "rule:" /etc/falco/rules.d/m3-rules.yaml
# Mong đợi: 3
```

---

### Q19 – Audit Log Investigation (5 điểm) [Monitoring/Runtime]

File `/tmp/m3-audit.log` chứa audit log của một sự cố bảo mật.

**Yêu cầu:**
Phân tích và ghi câu trả lời vào `/tmp/m3-audit-answers.txt`:
- Q19a: User nào đã tạo ClusterRoleBinding?
- Q19b: ServiceAccount nào đã list secrets ở namespace `m3-prod`?
- Q19c: Có bao nhiêu lần anonymous user cố truy cập API?
- Q19d: Pod nào bị xóa và bởi user nào?

**Kiểm tra:**
```bash
cat /tmp/m3-audit-answers.txt
```

---

### Q20 – Cilium IPsec Encryption (5 điểm) [Monitoring/Runtime]

**Yêu cầu:**
- Tạo file `/tmp/m3-cilium-config.yaml` chứa Cilium ConfigMap với IPsec encryption được bật:
  - `enable-ipsec: "true"`
  - `encryption: "ipsec"`
  - `encryption-node-encryption: "true"`
- Giải thích sự khác biệt giữa IPsec và WireGuard trong Cilium, ghi vào `/tmp/m3-cilium-notes.txt`

**Kiểm tra:**
```bash
cat /tmp/m3-cilium-config.yaml | grep "enable-ipsec"
cat /tmp/m3-cilium-notes.txt
```

---

### Q21 – Runtime Threat Response (5 điểm) [Monitoring/Runtime]

Pod `suspicious-pod` trong namespace `m3-runtime` đang chạy với nhiều vấn đề bảo mật.

**Yêu cầu:**
- Kiểm tra pod và ghi danh sách vấn đề vào `/tmp/m3-threat-report.txt`
- Xóa pod `suspicious-pod`
- Tạo pod `secure-replacement` với đầy đủ security hardening:
  - `readOnlyRootFilesystem: true`, `runAsNonRoot: true`, `runAsUser: 1000`
  - `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`
  - `seccompProfile.type: RuntimeDefault`, emptyDir tại `/tmp`

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
