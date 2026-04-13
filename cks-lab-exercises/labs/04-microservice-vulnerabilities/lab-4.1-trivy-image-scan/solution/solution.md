# Giải pháp – Lab 4.1 Trivy Image Scan

## Bước 1: Quét image nginx:1.14.0

```bash
# Quét toàn bộ lỗ hổng
trivy image nginx:1.14.0

# Chỉ hiển thị CRITICAL
trivy image --severity CRITICAL nginx:1.14.0
```

Output mẫu (rút gọn):
```
nginx:1.14.0 (debian 9.13)
==========================
Total: 152 (CRITICAL: 23, HIGH: 56, MEDIUM: 43, LOW: 30)

┌──────────────────┬────────────────┬──────────┬───────────────────┬───────────────┐
│     Library      │ Vulnerability  │ Severity │ Installed Version │ Fixed Version │
├──────────────────┼────────────────┼──────────┼───────────────────┼───────────────┤
│ openssl          │ CVE-2019-1543  │ CRITICAL │ 1.1.0l-1~deb9u1   │ 1.1.0l-1~deb9u3│
│ libssl1.0.2      │ CVE-2019-1559  │ CRITICAL │ 1.0.2r-1~deb9u1   │ 1.0.2t-1~deb9u1│
└──────────────────┴────────────────┴──────────┴───────────────────┴───────────────┘
```

**Nhận xét:** `nginx:1.14.0` dựa trên Debian 9 (Stretch) đã hết hỗ trợ, chứa nhiều lỗ hổng CRITICAL trong các package hệ thống như `openssl`, `libssl`, `libc6`.

## Bước 2: Quét image nginx:1.25-alpine để so sánh

```bash
trivy image --severity CRITICAL nginx:1.25-alpine
```

Output mẫu:
```
nginx:1.25-alpine (alpine 3.18.x)
==================================
Total: 0 (CRITICAL: 0)
```

**Nhận xét:** `nginx:1.25-alpine` dựa trên Alpine Linux với ít package hơn, không có lỗ hổng CRITICAL.

## Bước 3: Xóa pod cũ và tạo pod mới với image an toàn

```bash
# Xóa pod đang dùng image cũ
kubectl delete pod web-app -n trivy-lab

# Tạo pod mới với image nginx:1.25-alpine
kubectl run web-app \
  --image=nginx:1.25-alpine \
  --namespace=trivy-lab \
  --restart=Never

# Xác minh pod đang Running
kubectl get pod web-app -n trivy-lab
```

Output mong đợi:
```
NAME      READY   STATUS    RESTARTS   AGE
web-app   1/1     Running   0          10s
```

## Bước 4: Xác minh image đã được cập nhật

```bash
kubectl get pod web-app -n trivy-lab -o jsonpath='{.spec.containers[0].image}'
# nginx:1.25-alpine
```

## Bước 5: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] trivy đã được cài đặt
[PASS] Pod 'web-app' tồn tại trong namespace 'trivy-lab' và đang Running
[PASS] Pod 'web-app' đang sử dụng image nginx:1.25-alpine (image an toàn hơn)
---
Kết quả: 3/3 tiêu chí đạt
```

## Tóm tắt lệnh trivy quan trọng

| Lệnh | Mục đích |
|------|----------|
| `trivy image <image>` | Quét toàn bộ lỗ hổng của image |
| `trivy image --severity CRITICAL,HIGH <image>` | Chỉ hiển thị CRITICAL và HIGH |
| `trivy image --format json -o result.json <image>` | Xuất kết quả dạng JSON |
| `trivy image --ignore-unfixed <image>` | Chỉ hiển thị lỗ hổng đã có bản vá |
| `trivy image --exit-code 1 --severity CRITICAL <image>` | Thoát với code 1 nếu có CRITICAL (dùng trong CI/CD) |
| `trivy fs /path/to/project` | Quét filesystem (source code, IaC) |
| `trivy config /path/to/manifests` | Quét Kubernetes manifest |

## Tích hợp trivy vào CI/CD

```yaml
# Ví dụ GitHub Actions
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'nginx:1.25-alpine'
    format: 'table'
    exit-code: '1'
    severity: 'CRITICAL,HIGH'
```

## Giải thích bảo mật

### Tại sao nginx:1.14.0 nguy hiểm?

- Phát hành năm 2018, dựa trên Debian 9 (Stretch) đã hết EOL từ 2022
- Chứa nhiều CVE trong các package hệ thống: openssl, glibc, libssl
- Không nhận được security patch từ upstream

### Tại sao nginx:1.25-alpine an toàn hơn?

- Alpine Linux có attack surface nhỏ hơn (ít package hơn)
- Được cập nhật thường xuyên với security patches
- Kích thước image nhỏ hơn (~50MB vs ~200MB)
- Sử dụng musl libc thay vì glibc — ít lỗ hổng hơn
