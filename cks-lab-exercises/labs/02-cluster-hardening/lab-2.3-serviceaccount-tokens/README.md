# Lab 2.3 – ServiceAccount Token Automount

**Domain:** Cluster Hardening (15%)
**Thời gian ước tính:** 15 phút
**Độ khó:** Cơ bản

---

## Mục tiêu

- Hiểu cơ chế automount ServiceAccount token trong Kubernetes
- Vô hiệu hóa automount token trên ServiceAccount `web-sa` trong namespace `token-lab`
- Vô hiệu hóa automount token trên pod `web-app`
- Xác minh token không xuất hiện trong pod sau khi vô hiệu hóa

---

## Lý thuyết

### ServiceAccount Token là gì?

Mỗi pod trong Kubernetes mặc định được gắn một **ServiceAccount** và token của nó được **tự động mount** vào pod tại:
```
/var/run/secrets/kubernetes.io/serviceaccount/token
```

Token này là **JWT (JSON Web Token)** cho phép pod xác thực với kube-apiserver. Pod có thể dùng token này để gọi Kubernetes API.

### Tại sao automount là rủi ro bảo mật?

Hầu hết ứng dụng (web server, database, worker...) **không cần** gọi Kubernetes API. Nhưng token vẫn được mount mặc định. Nếu pod bị compromise:

```
Attacker → RCE vào pod → Đọc token → Gọi K8s API → Enumerate cluster → Lateral movement
```

Ngay cả ServiceAccount với quyền tối thiểu cũng có thể dùng để:
- `kubectl get pods --all-namespaces` (nếu có quyền list pods)
- Enumerate secrets, configmaps
- Thu thập thông tin về cluster topology

### Cách tắt automount

**Tắt ở ServiceAccount level** (ảnh hưởng tất cả pod dùng SA này):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-sa
automountServiceAccountToken: false  # Tắt cho tất cả pod
```

**Tắt ở Pod level** (ghi đè SA setting):
```yaml
spec:
  automountServiceAccountToken: false  # Ghi đè SA setting
  serviceAccountName: my-sa
```

**Thứ tự ưu tiên:** Pod spec > ServiceAccount spec

### Khi nào NÊN và KHÔNG NÊN tắt?

| Loại ứng dụng | Tắt automount? | Lý do |
|--------------|---------------|-------|
| Web server, API gateway | ✅ Nên tắt | Không cần K8s API |
| Worker, batch job | ✅ Nên tắt | Thường không cần K8s API |
| Operator, controller | ❌ Không tắt | Cần watch/update resources |
| Service mesh sidecar | ❌ Không tắt | Cần API để lấy config |

### Xác minh token không được mount

```bash
# Kiểm tra thư mục secrets trong pod
kubectl exec my-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
# Nếu tắt: "No such file or directory"
# Nếu bật: "ca.crt  namespace  token"

# Kiểm tra qua pod spec
kubectl get pod my-pod -o jsonpath='{.spec.automountServiceAccountToken}'
# Mong đợi: false
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty SaaS. Trong quá trình audit, bạn phát hiện nhiều pod đang tự động mount ServiceAccount token dù không cần giao tiếp với Kubernetes API. Điều này vi phạm nguyên tắc least-privilege — nếu một pod bị compromise, kẻ tấn công có thể dùng token để truy cập API server.

Nhiệm vụ của bạn là:
1. Vô hiệu hóa automount token trên ServiceAccount `web-sa`
2. Vô hiệu hóa automount token trên pod `web-app`
3. Xác minh token không còn xuất hiện trong pod

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra trạng thái hiện tại

Xem ServiceAccount và pod hiện tại:

```bash
# Xem ServiceAccount
kubectl get serviceaccount web-sa -n token-lab -o yaml

# Xem pod
kubectl get pod web-app -n token-lab -o yaml

# Kiểm tra token có được mount không
kubectl exec web-app -n token-lab -- \
  ls /var/run/secrets/kubernetes.io/serviceaccount/
```

Bạn sẽ thấy token đang được mount mặc định.

### Bước 2: Vô hiệu hóa automount trên ServiceAccount

Patch ServiceAccount để tắt automount:

```bash
kubectl patch serviceaccount web-sa -n token-lab \
  -p '{"automountServiceAccountToken": false}'
```

Xác minh thay đổi:

```bash
kubectl get serviceaccount web-sa -n token-lab -o yaml | grep automount
```

### Bước 3: Vô hiệu hóa automount trên pod

Pod là immutable sau khi tạo — cần xóa và tạo lại với `automountServiceAccountToken: false`.

Xóa pod hiện tại:

```bash
kubectl delete pod web-app -n token-lab
```

Tạo lại pod với automount bị tắt:

```bash
kubectl run web-app -n token-lab \
  --image=nginx:alpine \
  --overrides='{"spec":{"serviceAccountName":"web-sa","automountServiceAccountToken":false}}'
```

Hoặc dùng manifest YAML:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
  namespace: token-lab
spec:
  serviceAccountName: web-sa
  automountServiceAccountToken: false
  containers:
  - name: web-app
    image: nginx:alpine
```

### Bước 4: Xác minh token không được mount

```bash
# Chờ pod Running
kubectl wait --for=condition=Ready pod/web-app -n token-lab --timeout=60s

# Kiểm tra thư mục secrets — phải báo lỗi hoặc không có file token
kubectl exec web-app -n token-lab -- \
  ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1 || echo "Thư mục không tồn tại"

# Hoặc kiểm tra trực tiếp file token
kubectl exec web-app -n token-lab -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>&1 || echo "Token không tồn tại"
```

---

## Tiêu chí kiểm tra

- [ ] ServiceAccount `web-sa` có `automountServiceAccountToken: false`
- [ ] Pod `web-app` có `automountServiceAccountToken: false`
- [ ] File token KHÔNG tồn tại tại `/var/run/secrets/kubernetes.io/serviceaccount/token` trong pod

---

## Gợi ý

<details>
<summary>Gợi ý 1: Sự khác biệt giữa tắt automount ở SA và ở Pod</summary>

Có hai nơi để kiểm soát automount token:

1. **ServiceAccount level**: Ảnh hưởng đến tất cả pod dùng SA đó (trừ khi pod override)
2. **Pod level**: Ghi đè cài đặt của SA cho pod cụ thể đó

Thứ tự ưu tiên: **Pod spec > ServiceAccount spec**

```yaml
# SA tắt automount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web-sa
automountServiceAccountToken: false  # Mặc định tắt cho tất cả pod

---
# Pod bật lại (override SA)
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: web-sa
  automountServiceAccountToken: true  # Ghi đè SA — token VẪN được mount
```

Để đảm bảo token không được mount, cần tắt ở **cả hai nơi** hoặc chỉ ở pod level.

</details>

<details>
<summary>Gợi ý 2: Tại sao phải xóa và tạo lại pod?</summary>

Pod spec là immutable sau khi tạo — bạn không thể `kubectl patch` trường `automountServiceAccountToken` trên pod đang chạy. Cần:

```bash
# Xóa pod cũ
kubectl delete pod web-app -n token-lab

# Tạo lại với cấu hình mới
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: web-app
  namespace: token-lab
spec:
  serviceAccountName: web-sa
  automountServiceAccountToken: false
  containers:
  - name: web-app
    image: nginx:alpine
EOF
```

</details>

<details>
<summary>Gợi ý 3: Cách xác minh token không được mount</summary>

```bash
# Cách 1: Kiểm tra thư mục
kubectl exec web-app -n token-lab -- \
  ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1

# Nếu token bị tắt: "ls: /var/run/secrets/kubernetes.io/serviceaccount/: No such file or directory"
# Nếu token vẫn mount: sẽ thấy các file: ca.crt, namespace, token

# Cách 2: Kiểm tra trực tiếp file token
kubectl exec web-app -n token-lab -- \
  test -f /var/run/secrets/kubernetes.io/serviceaccount/token && echo "Token tồn tại" || echo "Token không tồn tại"

# Cách 3: Xem pod spec
kubectl get pod web-app -n token-lab -o jsonpath='{.spec.automountServiceAccountToken}'
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

### Tại sao cần tắt automount ServiceAccount token?

Mặc định, Kubernetes tự động mount ServiceAccount token vào mọi pod tại đường dẫn `/var/run/secrets/kubernetes.io/serviceaccount/token`. Token này cho phép pod xác thực với Kubernetes API server.

**Rủi ro bảo mật:**
- Nếu pod bị compromise (RCE, container escape), kẻ tấn công có thể đọc token
- Token có thể dùng để gọi Kubernetes API với quyền của ServiceAccount
- Ngay cả SA với quyền tối thiểu cũng có thể dùng để enumerate cluster resources

**Nguyên tắc least-privilege:**
- Nếu pod không cần giao tiếp với Kubernetes API, không nên có token
- Ví dụ: web server, database, worker process thường không cần API access

### Khi nào NÊN tắt automount?

- Pod chỉ phục vụ traffic từ user (web app, API gateway)
- Pod xử lý dữ liệu nội bộ không cần biết về cluster
- Pod chạy third-party software không tin tưởng

### Khi nào KHÔNG nên tắt?

- Pod cần đọc ConfigMap/Secret từ API (dùng client-go, fabric8)
- Operator/controller cần watch resources
- Pod dùng Kubernetes Downward API
- Service mesh sidecar (Istio, Linkerd) cần API access

### Trong CKS Exam

Câu hỏi thường yêu cầu:
1. Tắt automount trên SA hoặc pod cụ thể
2. Xác minh token không còn trong pod
3. Giải thích tại sao đây là best practice

---

## Tham khảo

- [Kubernetes ServiceAccount Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#opt-out-of-api-credential-automounting)
- [CKS Exam Curriculum – Cluster Hardening](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- [RBAC Best Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
