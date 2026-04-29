# Lab 1.5 – Authentication với Certificate và ServiceAccount

**Domain:** Cluster Setup (15%)
**Thời gian ước tính:** 25 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Hiểu cơ chế xác thực (authentication) trong Kubernetes: Certificate vs ServiceAccount Token
- Tạo user `dev-user` bằng cách ký certificate với Kubernetes CA
- Tạo kubeconfig cho user mới với quyền hạn chế
- Tạo ServiceAccount với `automountServiceAccountToken: false`
- Xác minh user chỉ có quyền được cấp, không có quyền khác

---

## Lý thuyết

### Authentication trong Kubernetes là gì?

Kubernetes không có khái niệm "user account" built-in — không có database lưu username/password. Thay vào đó, Kubernetes hỗ trợ nhiều phương thức xác thực:

| Phương thức | Dùng cho | Cơ chế |
|------------|---------|--------|
| **X.509 Certificate** | Human users, external tools | Client cert được ký bởi Kubernetes CA |
| **ServiceAccount Token** | Pod, in-cluster workload | JWT token được mount vào pod |
| **OIDC Token** | SSO, enterprise identity | Tích hợp với IdP (Google, Okta...) |
| **Bootstrap Token** | Thêm node vào cluster | Token tạm thời khi join node |

### X.509 Certificate Authentication

Khi bạn dùng `kubectl`, nó gửi **client certificate** đến API server. API server kiểm tra:
1. Certificate có được ký bởi Kubernetes CA không?
2. Certificate còn hạn không?
3. Subject của certificate là gì? (dùng làm username)

```
kubectl → [client cert] → kube-apiserver → [verify CA signature] → username = cert.Subject.CN
```

**Cấu trúc Subject trong certificate:**
- `CN` (Common Name) = **username** trong Kubernetes
- `O` (Organization) = **group** trong Kubernetes

Ví dụ: `CN=dev-user, O=developers` → username `dev-user`, thuộc group `developers`

### Quy trình tạo user bằng Certificate

```
1. Tạo private key (openssl genrsa)
2. Tạo CSR - Certificate Signing Request (openssl req)
3. Tạo CertificateSigningRequest object trong K8s
4. Approve CSR (kubectl certificate approve)
5. Lấy certificate đã ký (kubectl get csr -o jsonpath)
6. Tạo kubeconfig với certificate mới
```

### CertificateSigningRequest (CSR) trong Kubernetes

Kubernetes có API để ký certificate:

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-user
spec:
  request: <base64-encoded-CSR>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # 24 giờ
  usages:
  - client auth
```

Sau khi approve, certificate được ký bởi Kubernetes CA và có thể dùng để xác thực.

### ServiceAccount vs User Certificate

| | User Certificate | ServiceAccount |
|---|---|---|
| Dùng cho | Human users, CI/CD tools | Pod, in-cluster workload |
| Lưu trữ | File (kubeconfig) | Secret trong cluster |
| Revoke | Không thể revoke (phải chờ hết hạn) | Xóa Secret là revoke ngay |
| Rotation | Tạo cert mới, xóa cert cũ | Kubernetes tự rotate |
| Scope | Cluster-wide | Namespace-scoped |

---

## Bối cảnh

Bạn là kỹ sư bảo mật cần cấp quyền truy cập cluster cho một developer mới. Theo nguyên tắc least-privilege:
- Developer chỉ được đọc pod trong namespace `dev-ns`
- Developer không được có quyền gì khác
- Quyền truy cập phải có thể revoke khi cần

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình với quyền cluster-admin
- `openssl` đã được cài đặt

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Tạo private key và CSR cho user

```bash
# Tạo thư mục làm việc
mkdir -p /tmp/user-cert-lab
cd /tmp/user-cert-lab

# Tạo private key
openssl genrsa -out dev-user.key 2048

# Tạo CSR với CN=dev-user (username) và O=developers (group)
openssl req -new \
  -key dev-user.key \
  -out dev-user.csr \
  -subj "/CN=dev-user/O=developers"

# Xem nội dung CSR
openssl req -in dev-user.csr -text -noout | grep -E "Subject:|Public Key"
```

### Bước 2: Tạo CertificateSigningRequest trong Kubernetes

```bash
# Encode CSR thành base64
CSR_BASE64=$(cat dev-user.csr | base64 | tr -d '\n')

# Tạo CSR object trong Kubernetes
kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-user
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

# Xem trạng thái CSR
kubectl get csr dev-user
# STATUS: Pending
```

### Bước 3: Approve CSR

```bash
# Approve CSR (ký certificate bằng Kubernetes CA)
kubectl certificate approve dev-user

# Xem trạng thái sau khi approve
kubectl get csr dev-user
# STATUS: Approved,Issued
```

### Bước 4: Lấy certificate đã ký

```bash
# Lấy certificate từ CSR object
kubectl get csr dev-user \
  -o jsonpath='{.status.certificate}' | base64 -d > /tmp/user-cert-lab/dev-user.crt

# Xem thông tin certificate
openssl x509 -in /tmp/user-cert-lab/dev-user.crt -text -noout | \
  grep -E "Subject:|Issuer:|Not After"
```

### Bước 5: Tạo kubeconfig cho user mới

```bash
# Lấy thông tin cluster hiện tại
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Tạo kubeconfig cho dev-user
cat > /tmp/user-cert-lab/dev-user.kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA_DATA}
    server: ${CLUSTER_SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: dev-user
    namespace: dev-ns
  name: dev-user-context
current-context: dev-user-context
users:
- name: dev-user
  user:
    client-certificate: /tmp/user-cert-lab/dev-user.crt
    client-key: /tmp/user-cert-lab/dev-user.key
EOF

echo "Kubeconfig đã được tạo tại: /tmp/user-cert-lab/dev-user.kubeconfig"
```

### Bước 6: Cấp quyền cho user bằng RBAC

```bash
# Tạo Role cho phép đọc pod trong dev-ns
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev-ns
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF

# Tạo RoleBinding gắn Role với user dev-user
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-user-pod-reader
  namespace: dev-ns
subjects:
- kind: User
  name: dev-user        # Phải khớp với CN trong certificate
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Bước 7: Kiểm tra quyền của user mới

```bash
# Test với kubeconfig của dev-user
export KUBECONFIG=/tmp/user-cert-lab/dev-user.kubeconfig

# Phải thành công — có quyền list pods trong dev-ns
kubectl get pods -n dev-ns

# Phải thất bại — không có quyền list secrets
kubectl get secrets -n dev-ns

# Phải thất bại — không có quyền trong namespace khác
kubectl get pods -n default

# Phải thất bại — không có quyền xóa pod
kubectl delete pod --all -n dev-ns

# Khôi phục kubeconfig gốc
unset KUBECONFIG
```

### Bước 8: Tạo ServiceAccount với automount disabled

```bash
# Tạo ServiceAccount cho workload không cần K8s API
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: dev-ns
automountServiceAccountToken: false
EOF

# Xác minh
kubectl get serviceaccount restricted-sa -n dev-ns -o yaml | grep automount
# automountServiceAccountToken: false

# Tạo pod dùng SA này
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: dev-ns
spec:
  serviceAccountName: restricted-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

# Xác minh token không được mount
kubectl exec restricted-pod -n dev-ns -- \
  ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1 || echo "Token không được mount"
```

### Bước 9: Xóa CSR khi không cần nữa

```bash
# Xóa CSR object (certificate đã được lấy rồi)
kubectl delete csr dev-user

# Xem danh sách CSR còn lại
kubectl get csr
```

### Bước 10: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] File `/tmp/user-cert-lab/dev-user.crt` tồn tại và là certificate hợp lệ với CN=dev-user
- [ ] RoleBinding `dev-user-pod-reader` tồn tại trong namespace `dev-ns`
- [ ] ServiceAccount `restricted-sa` trong `dev-ns` có `automountServiceAccountToken: false`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Tại sao dùng CN và O trong certificate?</summary>

Kubernetes đọc thông tin từ certificate để xác định identity:
- `CN` (Common Name) → **username** trong Kubernetes RBAC
- `O` (Organization) → **group** trong Kubernetes RBAC

Ví dụ:
```bash
# User thuộc group "system:masters" → cluster-admin
openssl req -subj "/CN=admin/O=system:masters" ...

# User thông thường
openssl req -subj "/CN=dev-user/O=developers" ...
```

Khi tạo RoleBinding, `subjects[].name` phải khớp với `CN` trong certificate.

</details>

<details>
<summary>Gợi ý 2: Cách kiểm tra certificate đã ký</summary>

```bash
# Xem thông tin certificate
openssl x509 -in dev-user.crt -text -noout

# Kiểm tra CN (username)
openssl x509 -in dev-user.crt -noout -subject
# subject=CN=dev-user, O=developers

# Kiểm tra issuer (phải là Kubernetes CA)
openssl x509 -in dev-user.crt -noout -issuer

# Kiểm tra ngày hết hạn
openssl x509 -in dev-user.crt -noout -dates
```

</details>

<details>
<summary>Gợi ý 3: Revoke certificate trong Kubernetes</summary>

Kubernetes **không hỗ trợ revoke certificate** trực tiếp. Để vô hiệu hóa user:

1. **Xóa RoleBinding** — user không còn quyền gì (nhanh nhất)
2. **Rotate CA** — vô hiệu hóa tất cả certificate cũ (ảnh hưởng toàn cluster)
3. **Chờ certificate hết hạn** — dùng `expirationSeconds` ngắn khi tạo CSR

Đây là lý do tại sao **ServiceAccount** thường được ưu tiên hơn certificate cho workload — có thể revoke ngay bằng cách xóa Secret.

</details>

<details>
<summary>Gợi ý 4: Dùng kubectl certificate approve/deny</summary>

```bash
# Approve CSR
kubectl certificate approve <csr-name>

# Deny CSR (từ chối ký)
kubectl certificate deny <csr-name>

# Xem tất cả CSR
kubectl get csr

# Xem chi tiết CSR
kubectl describe csr <csr-name>
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các lệnh đầy đủ và giải thích chi tiết.

</details>

---

## Giải thích

### Tại sao dùng Certificate thay vì username/password?

Kubernetes không có built-in user database. Certificate-based authentication:
- **Không cần server lưu trữ** — chỉ cần verify chữ ký CA
- **Stateless** — API server không cần session
- **Phân tán** — mọi node đều có thể verify
- **Tiêu chuẩn** — X.509 là tiêu chuẩn PKI được dùng rộng rãi

### Vòng đời của User Certificate trong CKS

Trong kỳ thi CKS, bạn có thể được yêu cầu:
1. Tạo certificate cho user mới
2. Cấp quyền RBAC phù hợp
3. Xác minh user chỉ có quyền được cấp
4. Revoke quyền bằng cách xóa RoleBinding

### ServiceAccount vs User — khi nào dùng cái nào?

| Tình huống | Dùng gì |
|-----------|---------|
| Developer cần truy cập cluster | User Certificate |
| CI/CD pipeline cần deploy | ServiceAccount hoặc Certificate |
| Pod cần gọi K8s API | ServiceAccount |
| Pod không cần K8s API | ServiceAccount với `automountServiceAccountToken: false` |

---

## Tham khảo

- [Kubernetes Certificate Authentication](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
- [Managing TLS in a Cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
- [Configure Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [CKS Exam Curriculum – Cluster Setup](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
