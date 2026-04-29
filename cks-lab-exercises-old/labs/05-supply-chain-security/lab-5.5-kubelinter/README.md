# Lab 5.5 – KubeLinter Static Analysis

**Domain:** Supply Chain Security (20%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Cơ bản

---

## Mục tiêu

- Cài đặt và sử dụng `kube-linter` để phân tích static Kubernetes manifests
- Xác định các vấn đề bảo mật trong manifest: thiếu `runAsNonRoot`, `readOnlyRootFilesystem`, `resources.limits`
- Sửa các vấn đề và tạo manifest an toàn hơn đạt chuẩn kube-linter
- Hiểu sự khác biệt giữa KubeLinter, kubesec, và `trivy config`

---

## Lý thuyết

### KubeLinter là gì?

**KubeLinter** là công cụ static analysis của StackRox (Red Hat) chuyên cho Kubernetes manifests. Khác với kubesec (trả về điểm số), KubeLinter trả về **danh sách lỗi cụ thể kèm hướng dẫn sửa**:

```bash
kube-linter lint deployment.yaml
```

Output:
```
deployment.yaml: (object: default/my-app apps/v1, Kind=Deployment)
  container "app" does not have a read-only root file system
  (check: read-only-root-filesystem, remediation: Set readOnlyRootFilesystem to true...)

Error: found 3 lint errors
```

### Các checks quan trọng của KubeLinter

| Check | Vấn đề phát hiện | Fix |
|-------|-----------------|-----|
| `run-as-non-root` | Container chạy với UID 0 | `runAsNonRoot: true` |
| `read-only-root-filesystem` | Filesystem root có thể ghi | `readOnlyRootFilesystem: true` |
| `privileged-container` | Container chạy privileged | `privileged: false` |
| `unset-cpu-requirements` | Không có CPU limits | Thêm `resources.limits.cpu` |
| `unset-memory-requirements` | Không có memory limits | Thêm `resources.limits.memory` |
| `latest-tag` | Image dùng tag `latest` | Dùng tag cụ thể |
| `no-read-only-root-fs` | Alias của check trên | Như trên |

### So sánh KubeLinter vs kubesec vs trivy config

| | KubeLinter | kubesec | trivy config |
|---|---|---|---|
| Output | Danh sách lỗi + remediation | JSON score | Severity levels |
| Checks | 30+ K8s-specific | ~20 Pod security | Hàng trăm (K8s+Terraform+Docker) |
| Tùy chỉnh | `.kube-linter.yaml` | Hạn chế | `.trivyignore` |
| Khi nào dùng | Lint K8s manifest | Cần điểm số | Scan toàn bộ IaC |

### Cấu hình .kube-linter.yaml

```yaml
checks:
  addAllBuiltIn: true    # Dùng tất cả checks mặc định
  exclude:
    - "latest-tag"       # Bỏ qua check này (dev environment)
```

### Tích hợp CI/CD

```yaml
# GitHub Actions
- name: Lint Kubernetes manifests
  run: |
    kube-linter lint ./k8s/  # Exit code 1 nếu có lỗi → fail pipeline
```

### SecurityContext đầy đủ (để pass KubeLinter)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
resources:
  limits:
    cpu: "500m"
    memory: "128Mi"
  requests:
    cpu: "100m"
    memory: "64Mi"
```

---

## Bối cảnh

Bạn là DevSecOps engineer đang tích hợp static analysis vào CI/CD pipeline. Trước khi apply manifest lên cluster, bạn cần lint manifest để phát hiện sớm các vấn đề bảo mật.

Một developer đã tạo file `insecure-deployment.yaml` với nhiều vấn đề bảo mật: container chạy với quyền privileged, không có securityContext, không có resource limits, và dùng image tag `latest`. Nhiệm vụ của bạn là:

1. Cài đặt `kube-linter` và chạy lint trên manifest có vấn đề
2. Xác định các lỗi được báo cáo
3. Tạo `fixed-deployment.yaml` đã sửa tất cả vấn đề
4. Xác minh manifest đã sửa vượt qua kiểm tra

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- `kube-linter` sẽ được cài đặt trong bài lab này

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Cài đặt kube-linter

```bash
# Linux (amd64) – tải binary trực tiếp
curl -sSL https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz | tar xz
sudo mv kube-linter /usr/local/bin/

# Kiểm tra cài đặt
kube-linter version
```

### Bước 2: Chạy kube-linter lint trên manifest có vấn đề

```bash
# Xem manifest có vấn đề
cat /tmp/kubelinter-lab/insecure-deployment.yaml

# Chạy lint
kube-linter lint /tmp/kubelinter-lab/insecure-deployment.yaml
```

### Bước 3: Xác định các vấn đề được báo cáo

Kube-linter sẽ báo cáo các lỗi như:
- `run-as-non-root`: container không có `runAsNonRoot: true`
- `read-only-root-filesystem`: thiếu `readOnlyRootFilesystem: true`
- `no-read-only-root-fs`: filesystem root có thể ghi
- `unset-cpu-requirements`: không có `resources.limits.cpu`
- `unset-memory-requirements`: không có `resources.limits.memory`
- `privileged-container`: container chạy ở chế độ privileged

### Bước 4: Tạo fixed-deployment.yaml

Tạo file `/tmp/kubelinter-lab/fixed-deployment.yaml` với các sửa đổi:

```bash
cat > /tmp/kubelinter-lab/fixed-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          privileged: false
          capabilities:
            drop:
            - ALL
        resources:
          limits:
            cpu: "500m"
            memory: "128Mi"
          requests:
            cpu: "100m"
            memory: "64Mi"
EOF
```

### Bước 5: Verify – chạy lại lint trên manifest đã sửa

```bash
kube-linter lint /tmp/kubelinter-lab/fixed-deployment.yaml
```

Output mong đợi: không còn lỗi `run-as-non-root` và `read-only-root-filesystem`.

### Bước 6: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] `kube-linter` đã được cài đặt
- [ ] File `/tmp/kubelinter-lab/fixed-deployment.yaml` tồn tại
- [ ] `kube-linter lint fixed-deployment.yaml` không báo lỗi `run-as-non-root`
- [ ] `kube-linter lint fixed-deployment.yaml` không báo lỗi `read-only-root-filesystem`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cài đặt kube-linter trên các hệ điều hành khác nhau</summary>

```bash
# macOS (Homebrew)
brew install kube-linter

# Linux (amd64) – binary trực tiếp
curl -sSL https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz | tar xz
sudo mv kube-linter /usr/local/bin/

# Dùng Go
go install golang.stackrox.io/kube-linter/cmd/kube-linter@latest

# Kiểm tra
kube-linter version
```

</details>

<details>
<summary>Gợi ý 2: Hiểu output của kube-linter</summary>

Mỗi lỗi kube-linter báo cáo có dạng:

```
/tmp/kubelinter-lab/insecure-deployment.yaml: (object: default/insecure-app apps/v1, Kind=Deployment)
  container "app" does not have a read-only root file system (check: read-only-root-filesystem, remediation: Set readOnlyRootFilesystem to true in your container's securityContext.)
```

Các trường quan trọng:
- `check`: tên check bị vi phạm (dùng để grep trong verify.sh)
- `remediation`: hướng dẫn sửa cụ thể

</details>

<details>
<summary>Gợi ý 3: Các trường securityContext cần thêm</summary>

```yaml
securityContext:
  runAsNonRoot: true          # Không chạy với UID 0
  runAsUser: 1000             # Chạy với UID cụ thể
  readOnlyRootFilesystem: true  # Filesystem root chỉ đọc
  allowPrivilegeEscalation: false  # Không cho phép leo thang đặc quyền
  privileged: false           # Không chạy ở chế độ privileged
  capabilities:
    drop:
    - ALL                     # Drop tất cả Linux capabilities
```

</details>

<details>
<summary>Gợi ý 4: Thêm resource limits</summary>

```yaml
resources:
  limits:
    cpu: "500m"      # Tối đa 0.5 CPU core
    memory: "128Mi"  # Tối đa 128 MiB RAM
  requests:
    cpu: "100m"      # Yêu cầu tối thiểu 0.1 CPU core
    memory: "64Mi"   # Yêu cầu tối thiểu 64 MiB RAM
```

</details>

<details>
<summary>Gợi ý 5: Dùng .kube-linter.yaml để tùy chỉnh checks</summary>

File `/tmp/kubelinter-lab/.kube-linter.yaml` đã được tạo sẵn. Bạn có thể chạy:

```bash
kube-linter lint --config /tmp/kubelinter-lab/.kube-linter.yaml /tmp/kubelinter-lab/fixed-deployment.yaml
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

### Tại sao cần static analysis manifest?

Static analysis phát hiện vấn đề bảo mật **trước khi deploy** — sớm hơn nhiều so với runtime detection. Tích hợp vào CI/CD pipeline giúp:
- Ngăn manifest không an toàn vào production
- Giáo dục developer về best practices
- Tự động hóa security review

### So sánh KubeLinter vs kubesec vs trivy config

| Tiêu chí | KubeLinter | kubesec | trivy config |
|----------|-----------|---------|--------------|
| **Tập trung** | Kubernetes best practices | Điểm bảo mật Pod/Deployment | Misconfiguration đa nền tảng |
| **Output** | Danh sách lỗi + remediation | JSON score (-30 đến +7) | Severity levels (CRITICAL/HIGH) |
| **Checks** | 30+ checks Kubernetes-specific | ~20 checks Pod security | Hàng trăm checks (K8s, Terraform, Dockerfile) |
| **Tùy chỉnh** | `.kube-linter.yaml` | Hạn chế | `.trivyignore`, policy files |
| **CI/CD** | `--format json`, exit code | API hoặc binary | `--exit-code 1 --severity CRITICAL` |
| **Khi nào dùng** | Lint manifest K8s thuần túy | Cần điểm số bảo mật | Scan toàn bộ IaC (K8s + Terraform + Docker) |

**Khuyến nghị:**
- Dùng **KubeLinter** khi cần lint Kubernetes manifests với nhiều checks cụ thể
- Dùng **kubesec** khi cần điểm số bảo mật để so sánh giữa các manifest
- Dùng **trivy config** khi cần scan toàn bộ IaC trong một pipeline duy nhất

### Các check quan trọng của KubeLinter

| Check | Mô tả | Remediation |
|-------|-------|-------------|
| `run-as-non-root` | Container chạy với UID 0 | `runAsNonRoot: true` |
| `read-only-root-filesystem` | Filesystem root có thể ghi | `readOnlyRootFilesystem: true` |
| `no-read-only-root-fs` | Alias của check trên | Như trên |
| `privileged-container` | Container chạy privileged | `privileged: false` |
| `unset-cpu-requirements` | Không có CPU limits | Thêm `resources.limits.cpu` |
| `unset-memory-requirements` | Không có memory limits | Thêm `resources.limits.memory` |
| `latest-tag` | Image dùng tag `latest` | Dùng tag cụ thể (ví dụ: `nginx:1.25`) |

### Tích hợp KubeLinter vào CI/CD

```yaml
# GitHub Actions example
- name: Lint Kubernetes manifests
  run: |
    kube-linter lint ./k8s/ --format json | jq .
    kube-linter lint ./k8s/  # exit code 1 nếu có lỗi
```

---

## Tham khảo

- [KubeLinter Documentation](https://docs.kubelinter.io/)
- [KubeLinter GitHub](https://github.com/stackrox/kube-linter)
- [Kubernetes Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [CKS Exam – Supply Chain Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- [kubesec.io](https://kubesec.io/)
- [Trivy Config Scanning](https://aquasecurity.github.io/trivy/latest/docs/target/kubernetes/)
