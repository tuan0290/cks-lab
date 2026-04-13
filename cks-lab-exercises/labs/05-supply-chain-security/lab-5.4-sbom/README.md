# Lab 5.4 – SBOM (Software Bill of Materials)

**Domain:** Supply Chain Security (20%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Dùng `syft` để tạo SBOM (Software Bill of Materials) cho image `nginx:1.25-alpine` ở định dạng SPDX-JSON
- Dùng `trivy` để quét SBOM tìm lỗ hổng bảo mật
- Ghi kết quả vào `/tmp/sbom-results/`
- Hiểu ý nghĩa của SBOM trong bảo mật chuỗi cung ứng phần mềm

---

## Bối cảnh

Bạn là kỹ sư bảo mật đang xây dựng quy trình kiểm tra bảo mật cho container images trước khi deploy. Một phần quan trọng của supply chain security là biết chính xác những gì có trong image — đây là mục đích của SBOM.

SBOM (Software Bill of Materials) là danh sách đầy đủ các thành phần phần mềm trong một artifact, tương tự như danh sách nguyên liệu trong sản xuất. SPDX (Software Package Data Exchange) là một trong những định dạng SBOM phổ biến nhất, được Linux Foundation phát triển.

Nhiệm vụ của bạn:
1. Tạo SBOM cho `nginx:1.25-alpine` ở định dạng SPDX-JSON bằng `syft`
2. Lưu SBOM vào `/tmp/sbom-results/nginx-sbom.json`
3. Quét SBOM tìm lỗ hổng bằng `trivy`
4. Lưu kết quả quét vào `/tmp/sbom-results/vuln-report.txt`

---

## Yêu cầu môi trường

- `syft` đã được cài đặt
- `trivy` đã được cài đặt
- Kết nối internet để pull image (hoặc image đã có trong local cache)

Cài đặt syft (nếu chưa có):
```bash
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
```

Cài đặt trivy (nếu chưa có):
```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
```

Chạy script khởi tạo môi trường:
```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Tạo SBOM với syft

```bash
# Tạo SBOM ở định dạng SPDX-JSON
syft nginx:1.25-alpine -o spdx-json=/tmp/sbom-results/nginx-sbom.json

# Xem tóm tắt SBOM
syft nginx:1.25-alpine

# Xem số lượng packages trong SBOM
cat /tmp/sbom-results/nginx-sbom.json | python3 -m json.tool | grep '"name"' | wc -l
```

### Bước 2: Kiểm tra nội dung SBOM

```bash
# Xem cấu trúc SBOM
cat /tmp/sbom-results/nginx-sbom.json | python3 -m json.tool | head -30

# Kiểm tra SPDX version
cat /tmp/sbom-results/nginx-sbom.json | python3 -c "import json,sys; d=json.load(sys.stdin); print('SPDX Version:', d.get('spdxVersion', 'N/A'))"

# Xem danh sách packages
cat /tmp/sbom-results/nginx-sbom.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
packages = d.get('packages', [])
print(f'Total packages: {len(packages)}')
for p in packages[:10]:
    print(f'  - {p.get(\"name\", \"?\")} {p.get(\"versionInfo\", \"?\")}')
print('  ...')
"
```

### Bước 3: Quét SBOM tìm lỗ hổng với trivy

```bash
# Quét SBOM bằng trivy
trivy sbom /tmp/sbom-results/nginx-sbom.json

# Lưu kết quả vào file
trivy sbom /tmp/sbom-results/nginx-sbom.json \
  --format table \
  --output /tmp/sbom-results/vuln-report.txt

# Xem kết quả
cat /tmp/sbom-results/vuln-report.txt
```

### Bước 4: Lọc lỗ hổng theo mức độ nghiêm trọng

```bash
# Chỉ xem CRITICAL và HIGH
trivy sbom /tmp/sbom-results/nginx-sbom.json \
  --severity CRITICAL,HIGH \
  --format table

# Đếm số lỗ hổng theo mức độ
trivy sbom /tmp/sbom-results/nginx-sbom.json \
  --format json 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
counts = {}
for result in data.get('Results', []):
    for vuln in result.get('Vulnerabilities', []):
        sev = vuln.get('Severity', 'UNKNOWN')
        counts[sev] = counts.get(sev, 0) + 1
for sev, count in sorted(counts.items()):
    print(f'{sev}: {count}')
"
```

### Bước 5: So sánh với image scan trực tiếp

```bash
# Quét image trực tiếp (để so sánh)
trivy image nginx:1.25-alpine --format table 2>/dev/null | tail -20

# Kết quả phải tương tự với SBOM scan
```

### Bước 6: Kiểm tra kết quả

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] File `/tmp/sbom-results/nginx-sbom.json` tồn tại và là SBOM hợp lệ (chứa `spdxVersion`)
- [ ] File `/tmp/sbom-results/vuln-report.txt` tồn tại
- [ ] SBOM chứa danh sách packages (không rỗng)

---

## Gợi ý

<details>
<summary>Gợi ý 1: syft hỗ trợ những định dạng SBOM nào?</summary>

```bash
# Xem tất cả định dạng output
syft --help | grep -A20 "output"

# Các định dạng phổ biến:
# spdx-json    - SPDX 2.3 JSON (khuyến nghị cho interoperability)
# spdx-tag-value - SPDX 2.3 tag-value format
# cyclonedx-json - CycloneDX JSON
# cyclonedx-xml  - CycloneDX XML
# syft-json    - Syft native format
# table        - Human-readable table (không dùng cho machine processing)
```

</details>

<details>
<summary>Gợi ý 2: Sự khác biệt giữa SPDX và CycloneDX</summary>

| | SPDX | CycloneDX |
|---|---|---|
| Tổ chức | Linux Foundation | OWASP |
| Phiên bản hiện tại | 2.3 | 1.5 |
| Định dạng | JSON, XML, RDF, tag-value | JSON, XML |
| Ứng dụng | License compliance, security | Security-focused |
| Công cụ hỗ trợ | syft, tern, spdx-tools | syft, cdxgen, grype |

Cả hai đều được chấp nhận trong industry. SPDX phổ biến hơn cho license compliance.

</details>

<details>
<summary>Gợi ý 3: trivy sbom vs trivy image</summary>

```bash
# trivy image: Quét trực tiếp từ image (cần pull image)
trivy image nginx:1.25-alpine

# trivy sbom: Quét từ SBOM file (không cần image, nhanh hơn)
trivy sbom /tmp/sbom-results/nginx-sbom.json

# Ưu điểm của SBOM-based scanning:
# - Không cần pull image mỗi lần quét
# - Có thể lưu trữ và audit SBOM
# - Tích hợp vào CI/CD pipeline dễ hơn
# - Chia sẻ SBOM với khách hàng/auditor
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các lệnh đầy đủ và cách phân tích SBOM.

</details>

---

## Giải thích

### SBOM là gì và tại sao quan trọng?

SBOM (Software Bill of Materials) là danh sách đầy đủ và chính xác các thành phần phần mềm trong một artifact, bao gồm:
- Tên và phiên bản của mỗi package/library
- License của mỗi component
- Dependency relationships
- Thông tin về nguồn gốc (provenance)

**Tại sao SBOM quan trọng trong CKS:**
- **Vulnerability management**: Biết chính xác những gì trong image để track CVEs
- **License compliance**: Đảm bảo không vi phạm license
- **Supply chain security**: Phát hiện malicious packages
- **Incident response**: Khi có CVE mới, biết ngay image nào bị ảnh hưởng

### SBOM trong CKS Exam (từ 10/2024)

Linux Foundation đã cập nhật CKS curriculum để nhấn mạnh Supply Chain Security, bao gồm:
- Tạo và phân tích SBOM
- Sử dụng `syft`, `grype`, `trivy` cho SBOM workflow
- Tích hợp SBOM vào CI/CD pipeline

### SPDX Format

SPDX-JSON là định dạng được khuyến nghị vì:
- Machine-readable và human-readable
- Được hỗ trợ bởi nhiều công cụ
- Là tiêu chuẩn ISO (ISO/IEC 5962:2021)

---

## Tham khảo

- [syft Documentation](https://github.com/anchore/syft)
- [SPDX Specification](https://spdx.github.io/spdx-spec/)
- [trivy SBOM Scanning](https://aquasecurity.github.io/trivy/latest/docs/target/sbom/)
- [CISA SBOM Resources](https://www.cisa.gov/sbom)
- [CKS Exam Curriculum – Supply Chain Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
