# Lab 5.2 – Static Analysis

**Domain:** Supply Chain Security (20%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Cơ bản

---

## Mục tiêu

- Sử dụng `kubesec` hoặc `trivy config` để phân tích static Kubernetes manifest
- Xác định các vấn đề bảo mật trong manifest (privileged container, hostPID)
- Sửa các vấn đề bảo mật và tạo manifest an toàn hơn

---

## Lý thuyết

### Static Analysis là gì?

**Static Analysis** (phân tích tĩnh) là kiểm tra code/config mà không cần chạy chương trình. Trong Kubernetes security, static analysis kiểm tra manifest YAML để phát hiện vấn đề bảo mật **trước khi deploy**.

Lợi ích: Phát hiện sớm → chi phí sửa thấp hơn nhiều so với phát hiện sau khi deploy.

### kubesec là gì?

**kubesec** là công cụ static analysis cho Kubernetes manifest, trả về **điểm số bảo mật** (-30 đến +7):

```bash
kubesec scan pod.yaml
```

Output:
```json
{
  "score": -30,
  "scoring": {
    "critical": [
      {
        "id": "Privileged",
        "selector": "containers[] .securityContext .privileged == true",
        "reason": "Privileged containers can allow almost completely unrestricted host access",
        "points": -30
      }
    ],
    "advise": [...]
  }
}
```

| Score | Ý nghĩa |
|-------|---------|
| < 0 | Critical security issues — cần sửa ngay |
| 0 | Baseline (không có điểm cộng hay trừ) |
| > 0 | Security best practices được áp dụng |

### trivy config là gì?

**trivy config** quét Kubernetes manifest, Dockerfile, Terraform... tìm misconfiguration:

```bash
trivy config pod.yaml
trivy config --severity HIGH,CRITICAL pod.yaml
```

### Các vấn đề bảo mật phổ biến trong manifest

| Vấn đề | Rủi ro | Fix |
|--------|--------|-----|
| `privileged: true` | Container có toàn quyền host | `privileged: false` |
| `hostPID: true` | Thấy tất cả process trên host | Xóa hoặc `false` |
| `hostNetwork: true` | Dùng network namespace của host | Xóa hoặc `false` |
| Không có `resources.limits` | Có thể chiếm toàn bộ tài nguyên node | Thêm limits |
| Image tag `latest` | Không xác định version | Dùng tag cụ thể |
| Không có `runAsNonRoot` | Container chạy với root | `runAsNonRoot: true` |

### Dockerfile best practices

```dockerfile
# Dùng multi-stage build để giảm kích thước image
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o myapp .

FROM gcr.io/distroless/static:nonroot  # Minimal base image
COPY --from=builder /app/myapp /myapp
USER nonroot:nonroot  # Chạy với user non-root
ENTRYPOINT ["/myapp"]
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật đang review một Kubernetes manifest trước khi deploy lên production. Manifest này được viết bởi một developer mới và có nhiều vấn đề bảo mật nghiêm trọng: container chạy ở chế độ privileged và sử dụng hostPID namespace của host.

Nhiệm vụ của bạn là:
1. Phân tích manifest `/tmp/insecure-manifest.yaml` bằng kubesec hoặc trivy config
2. Xác định các vấn đề bảo mật được phát hiện
3. Tạo manifest đã sửa tại `/tmp/fixed-manifest.yaml` không còn các vấn đề trên
4. Xác minh manifest đã sửa vượt qua kiểm tra bảo mật

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- `kubesec` hoặc `trivy` đã được cài đặt:
  - kubesec: [https://kubesec.io/](https://kubesec.io/)
  - trivy: [https://aquasecurity.github.io/trivy/](https://aquasecurity.github.io/trivy/)

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Xem manifest có vấn đề

```bash
cat /tmp/insecure-manifest.yaml
```

### Bước 2: Phân tích bằng kubesec

```bash
# Phân tích manifest bằng kubesec
kubesec scan /tmp/insecure-manifest.yaml

# Hoặc dùng kubesec API (không cần cài đặt)
curl -sSX POST --data-binary @/tmp/insecure-manifest.yaml https://v2.kubesec.io/scan | jq .
```

### Bước 3: Phân tích bằng trivy config (thay thế)

```bash
# Phân tích manifest bằng trivy config
trivy config /tmp/insecure-manifest.yaml

# Chỉ hiển thị lỗi CRITICAL và HIGH
trivy config --severity CRITICAL,HIGH /tmp/insecure-manifest.yaml
```

### Bước 4: Sửa các vấn đề bảo mật

Tạo file `/tmp/fixed-manifest.yaml` với các sửa đổi:
- Xóa hoặc đặt `privileged: false`
- Xóa hoặc đặt `hostPID: false`
- Thêm các security best practices khác

```bash
# Tạo manifest đã sửa
cp /tmp/insecure-manifest.yaml /tmp/fixed-manifest.yaml
# Chỉnh sửa file
nano /tmp/fixed-manifest.yaml
```

### Bước 5: Xác minh manifest đã sửa

```bash
# Kiểm tra lại bằng kubesec
kubesec scan /tmp/fixed-manifest.yaml

# Hoặc trivy config
trivy config /tmp/fixed-manifest.yaml
```

### Bước 6: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] File `/tmp/fixed-manifest.yaml` tồn tại
- [ ] File `/tmp/fixed-manifest.yaml` không chứa `privileged: true`
- [ ] File `/tmp/fixed-manifest.yaml` không chứa `hostPID: true`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cài đặt kubesec</summary>

```bash
# Linux (amd64)
curl -sSL https://github.com/controlplaneio/kubesec/releases/latest/download/kubesec_linux_amd64.tar.gz | tar xz
sudo mv kubesec /usr/local/bin/

# Kiểm tra cài đặt
kubesec version

# Hoặc dùng Docker
docker run -i kubesec/kubesec:512c5e0 scan /dev/stdin < /tmp/insecure-manifest.yaml
```

</details>

<details>
<summary>Gợi ý 2: Hiểu output của kubesec</summary>

kubesec trả về JSON với các trường:
- `score`: Điểm bảo mật (âm = nguy hiểm, dương = tốt)
- `scoring.critical`: Các vấn đề nghiêm trọng cần sửa ngay
- `scoring.advise`: Các cải tiến được khuyến nghị

Ví dụ output:
```json
{
  "score": -30,
  "scoring": {
    "critical": [
      {
        "id": "Privileged",
        "selector": "containers[] .securityContext .privileged == true",
        "reason": "Privileged containers can allow almost completely unrestricted host access",
        "points": -30
      }
    ]
  }
}
```

</details>

<details>
<summary>Gợi ý 3: Các vấn đề cần sửa trong manifest</summary>

Manifest gốc có hai vấn đề chính:

**1. `privileged: true`** — Container có toàn quyền truy cập host kernel
```yaml
# Sửa: xóa dòng này hoặc đặt false
securityContext:
  privileged: false  # hoặc xóa hoàn toàn
```

**2. `hostPID: true`** — Container có thể thấy tất cả process trên host
```yaml
# Sửa: xóa dòng này hoặc đặt false
spec:
  hostPID: false  # hoặc xóa hoàn toàn
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

### Tại sao `privileged: true` nguy hiểm?

Container privileged có gần như toàn quyền truy cập vào host kernel:
- Có thể mount bất kỳ filesystem nào của host
- Có thể thay đổi kernel parameters (sysctl)
- Có thể truy cập tất cả devices của host
- Có thể escape container và compromise toàn bộ node

### Tại sao `hostPID: true` nguy hiểm?

Khi `hostPID: true`, container chia sẻ PID namespace với host:
- Có thể thấy tất cả process đang chạy trên host
- Có thể gửi signal đến process của host
- Có thể đọc `/proc/<pid>/` của bất kỳ process nào trên host
- Có thể leak thông tin nhạy cảm từ process khác

### Static Analysis trong CI/CD

Tích hợp kubesec/trivy vào pipeline để phát hiện sớm:

```yaml
# GitHub Actions example
- name: Scan Kubernetes manifests
  run: |
    trivy config --exit-code 1 --severity CRITICAL ./k8s/
```

### Best practices cho SecurityContext

```yaml
securityContext:
  privileged: false
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
    - ALL
```

---

## Tham khảo

- [kubesec Documentation](https://kubesec.io/)
- [Trivy Config Scanning](https://aquasecurity.github.io/trivy/latest/docs/target/kubernetes/)
- [Kubernetes Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [CKS Exam – Supply Chain Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
