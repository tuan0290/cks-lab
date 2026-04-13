# Lab 4.1 – Trivy Image Scan

**Domain:** Minimize Microservice Vulnerabilities (20%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Cơ bản

---

## Mục tiêu

- Sử dụng `trivy image` để quét image `nginx:1.14.0` và xác định các lỗ hổng mức CRITICAL
- Phân tích kết quả quét và hiểu ý nghĩa của từng mức độ nghiêm trọng (CRITICAL, HIGH, MEDIUM, LOW)
- Thay thế image `nginx:1.14.0` bằng `nginx:1.25-alpine` để giảm thiểu lỗ hổng bảo mật

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty đang vận hành ứng dụng web trên Kubernetes. Trong quá trình audit bảo mật, bạn phát hiện pod `web-app` trong namespace `trivy-lab` đang sử dụng image `nginx:1.14.0` — một phiên bản cũ có nhiều lỗ hổng CRITICAL đã được công bố.

Nhiệm vụ của bạn là:
1. Quét image `nginx:1.14.0` bằng `trivy` để xác nhận các lỗ hổng CRITICAL
2. Xác định CVE cụ thể và mức độ ảnh hưởng
3. Cập nhật pod để sử dụng image `nginx:1.25-alpine` (phiên bản an toàn hơn)
4. Xác minh image mới không còn lỗ hổng CRITICAL

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- `trivy` đã được cài đặt: [https://aquasecurity.github.io/trivy/latest/getting-started/installation/](https://aquasecurity.github.io/trivy/latest/getting-started/installation/)
- Kết nối internet để pull image và cập nhật vulnerability database

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra pod hiện tại

```bash
# Xem pod đang chạy trong namespace trivy-lab
kubectl get pod web-app -n trivy-lab -o wide

# Xem image đang được sử dụng
kubectl get pod web-app -n trivy-lab -o jsonpath='{.spec.containers[0].image}'
```

### Bước 2: Quét image nginx:1.14.0 bằng trivy

```bash
# Quét toàn bộ lỗ hổng
trivy image nginx:1.14.0

# Chỉ hiển thị lỗ hổng CRITICAL và HIGH
trivy image --severity CRITICAL,HIGH nginx:1.14.0

# Chỉ hiển thị lỗ hổng CRITICAL
trivy image --severity CRITICAL nginx:1.14.0

# Xuất kết quả dạng JSON để phân tích chi tiết
trivy image --format json --output /tmp/nginx-scan.json nginx:1.14.0
```

### Bước 3: Phân tích kết quả quét

Xem xét output của trivy và ghi nhận:
- Tổng số lỗ hổng theo mức độ (CRITICAL, HIGH, MEDIUM, LOW)
- CVE ID của các lỗ hổng CRITICAL
- Package/library bị ảnh hưởng
- Phiên bản đã được vá (Fixed Version)

### Bước 4: Quét image nginx:1.25-alpine để so sánh

```bash
# Quét image mới để xác nhận ít lỗ hổng hơn
trivy image --severity CRITICAL nginx:1.25-alpine
```

### Bước 5: Cập nhật pod sử dụng image mới

```bash
# Xóa pod cũ và tạo lại với image mới
kubectl delete pod web-app -n trivy-lab

kubectl run web-app \
  --image=nginx:1.25-alpine \
  --namespace=trivy-lab \
  --restart=Never

# Xác minh pod đang Running với image mới
kubectl get pod web-app -n trivy-lab
kubectl get pod web-app -n trivy-lab -o jsonpath='{.spec.containers[0].image}'
```

### Bước 6: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Pod `web-app` trong namespace `trivy-lab` đang sử dụng image `nginx:1.25-alpine` (không phải `nginx:1.14.0`)
- [ ] Pod `web-app` đang ở trạng thái `Running`
- [ ] `trivy` đã được cài đặt và có thể chạy lệnh `trivy image`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cách đọc output của trivy</summary>

Output của `trivy image` có dạng:

```
nginx:1.14.0 (debian 9.13)
==========================
Total: 152 (CRITICAL: 23, HIGH: 56, MEDIUM: 43, LOW: 30)

┌──────────────────┬────────────────┬──────────┬───────────────────┬───────────────┬──────────────────────────────────────────────────────────────┐
│     Library      │ Vulnerability  │ Severity │ Installed Version │ Fixed Version │                            Title                             │
├──────────────────┼────────────────┼──────────┼───────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ openssl          │ CVE-2019-1543  │ CRITICAL │ 1.1.0l-1~deb9u1   │ 1.1.0l-1~deb9u3│ openssl: ChaCha20-Poly1305 with long nonces                 │
```

Các cột quan trọng:
- **Library**: Package bị ảnh hưởng
- **Vulnerability**: CVE ID
- **Severity**: Mức độ nghiêm trọng
- **Installed Version**: Phiên bản hiện tại
- **Fixed Version**: Phiên bản đã được vá (nếu có)

</details>

<details>
<summary>Gợi ý 2: Tại sao dùng alpine image?</summary>

Image `nginx:1.25-alpine` dựa trên Alpine Linux — một distro tối giản với:
- Ít package hơn → ít attack surface hơn
- Kích thước nhỏ hơn (~50MB so với ~200MB của Debian-based)
- Ít lỗ hổng hơn vì ít dependency hơn

Khi quét `nginx:1.25-alpine`, bạn sẽ thấy số lượng lỗ hổng CRITICAL giảm đáng kể so với `nginx:1.14.0`.

</details>

<details>
<summary>Gợi ý 3: Cập nhật image của pod đang chạy</summary>

Pod trong Kubernetes là immutable — không thể thay đổi image của pod đang chạy trực tiếp. Có hai cách:

**Cách 1: Xóa và tạo lại pod**
```bash
kubectl delete pod web-app -n trivy-lab
kubectl run web-app --image=nginx:1.25-alpine --namespace=trivy-lab --restart=Never
```

**Cách 2: Dùng kubectl set image (cho Deployment)**
```bash
kubectl set image deployment/web-app nginx=nginx:1.25-alpine -n trivy-lab
```

Trong bài lab này, `web-app` là Pod (không phải Deployment), nên dùng Cách 1.

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### Tại sao quét image quan trọng?

Container image là tập hợp các layer chứa OS packages, libraries, và application code. Mỗi package có thể chứa lỗ hổng bảo mật (CVE). Nếu không quét image trước khi deploy, bạn có thể vô tình đưa lỗ hổng vào production.

### Trivy hoạt động như thế nào?

Trivy quét image bằng cách:
1. Pull image và extract các layer
2. Phân tích package manager database (dpkg, rpm, apk, v.v.)
3. So sánh với vulnerability database (NVD, GitHub Advisory, v.v.)
4. Báo cáo các CVE tìm thấy kèm mức độ nghiêm trọng

### Mức độ nghiêm trọng CVE

| Mức độ | CVSS Score | Ý nghĩa |
|--------|-----------|---------|
| CRITICAL | 9.0 – 10.0 | Có thể bị khai thác từ xa, không cần xác thực |
| HIGH | 7.0 – 8.9 | Ảnh hưởng nghiêm trọng, cần vá ngay |
| MEDIUM | 4.0 – 6.9 | Ảnh hưởng vừa phải, cần theo dõi |
| LOW | 0.1 – 3.9 | Ảnh hưởng thấp, vá khi có điều kiện |

### Best practices cho image security

- Luôn dùng image tag cụ thể (không dùng `latest`)
- Ưu tiên dùng distroless hoặc alpine-based image
- Tích hợp trivy vào CI/CD pipeline để quét trước khi push
- Thiết lập policy từ chối deploy image có lỗ hổng CRITICAL

---

## Tham khảo

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Trivy Image Scanning](https://aquasecurity.github.io/trivy/latest/docs/target/container_image/)
- [NVD – National Vulnerability Database](https://nvd.nist.gov/)
- [CKS Exam Curriculum – Minimize Microservice Vulnerabilities](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
