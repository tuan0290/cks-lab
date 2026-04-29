# Giải pháp mẫu – Lab 5.4: SBOM (Software Bill of Materials)

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## Bước 1: Cài đặt công cụ

```bash
# Cài đặt syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
syft version

# Cài đặt trivy (nếu chưa có)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
trivy --version

# Tạo thư mục kết quả
mkdir -p /tmp/sbom-results
```

---

## Bước 2: Tạo SBOM với syft

```bash
# Tạo SBOM ở định dạng SPDX-JSON
syft nginx:1.25-alpine -o spdx-json=/tmp/sbom-results/nginx-sbom.json

# Xem tóm tắt (human-readable)
syft nginx:1.25-alpine

# Xem nội dung SBOM
cat /tmp/sbom-results/nginx-sbom.json | python3 -m json.tool | head -50
```

Kết quả mẫu (tóm tắt):
```
NAME                    VERSION                TYPE
alpine-baselayout       3.4.3-r2               apk
alpine-baselayout-data  3.4.3-r2               apk
alpine-keys             2.4-r1                 apk
apk-tools               2.14.0-r5              apk
busybox                 1.36.1-r15             apk
...
nginx                   1.25.3-r0              apk
...
```

---

## Bước 3: Kiểm tra nội dung SBOM

```bash
# Xem SPDX version
python3 -c "
import json
with open('/tmp/sbom-results/nginx-sbom.json') as f:
    d = json.load(f)
print('SPDX Version:', d.get('spdxVersion'))
print('Document Name:', d.get('name'))
print('Created:', d.get('creationInfo', {}).get('created'))
print('Total packages:', len(d.get('packages', [])))
"

# Xem danh sách packages
python3 -c "
import json
with open('/tmp/sbom-results/nginx-sbom.json') as f:
    d = json.load(f)
packages = d.get('packages', [])
print(f'Total: {len(packages)} packages')
print()
for p in sorted(packages, key=lambda x: x.get('name', '')):
    name = p.get('name', 'N/A')
    version = p.get('versionInfo', 'N/A')
    license_info = p.get('licenseConcluded', 'N/A')
    print(f'{name:40} {version:20} {license_info}')
"
```

---

## Bước 4: Quét SBOM tìm lỗ hổng với trivy

```bash
# Quét và hiển thị kết quả
trivy sbom /tmp/sbom-results/nginx-sbom.json

# Lưu kết quả vào file
trivy sbom /tmp/sbom-results/nginx-sbom.json \
  --format table \
  --output /tmp/sbom-results/vuln-report.txt

# Xem kết quả
cat /tmp/sbom-results/vuln-report.txt
```

---

## Bước 5: Phân tích kết quả

```bash
# Đếm lỗ hổng theo mức độ
trivy sbom /tmp/sbom-results/nginx-sbom.json \
  --format json 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
counts = {}
total = 0
for result in data.get('Results', []):
    for vuln in result.get('Vulnerabilities', []):
        sev = vuln.get('Severity', 'UNKNOWN')
        counts[sev] = counts.get(sev, 0) + 1
        total += 1
print(f'Total vulnerabilities: {total}')
print()
for sev in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'UNKNOWN']:
    if sev in counts:
        print(f'  {sev}: {counts[sev]}')
"

# Chỉ xem CRITICAL
trivy sbom /tmp/sbom-results/nginx-sbom.json \
  --severity CRITICAL \
  --format table 2>/dev/null

# Lưu báo cáo chi tiết với JSON format
trivy sbom /tmp/sbom-results/nginx-sbom.json \
  --format json \
  --output /tmp/sbom-results/vuln-report-detailed.json 2>/dev/null
```

---

## Bước 6: Tạo SBOM ở định dạng khác (tùy chọn)

```bash
# CycloneDX JSON
syft nginx:1.25-alpine -o cyclonedx-json=/tmp/sbom-results/nginx-sbom-cdx.json

# CycloneDX XML
syft nginx:1.25-alpine -o cyclonedx-xml=/tmp/sbom-results/nginx-sbom-cdx.xml

# SPDX tag-value (text format)
syft nginx:1.25-alpine -o spdx-tag-value=/tmp/sbom-results/nginx-sbom.spdx

# Quét CycloneDX SBOM với trivy
trivy sbom /tmp/sbom-results/nginx-sbom-cdx.json --format table 2>/dev/null
```

---

## Workflow SBOM trong CI/CD

```bash
#!/bin/bash
# Ví dụ CI/CD pipeline script

IMAGE="nginx:1.25-alpine"
SBOM_DIR="/tmp/sbom-results"
mkdir -p "$SBOM_DIR"

# 1. Build image (trong CI/CD thực tế)
# docker build -t myapp:latest .

# 2. Tạo SBOM
echo "Generating SBOM..."
syft "$IMAGE" -o spdx-json="$SBOM_DIR/sbom.json"

# 3. Quét lỗ hổng từ SBOM
echo "Scanning for vulnerabilities..."
trivy sbom "$SBOM_DIR/sbom.json" \
  --severity CRITICAL,HIGH \
  --exit-code 1 \
  --format table \
  --output "$SBOM_DIR/vuln-report.txt" 2>/dev/null

SCAN_EXIT=$?

# 4. Kiểm tra kết quả
if [ $SCAN_EXIT -ne 0 ]; then
  echo "CRITICAL/HIGH vulnerabilities found! Blocking deployment."
  cat "$SBOM_DIR/vuln-report.txt"
  exit 1
else
  echo "No CRITICAL/HIGH vulnerabilities. Proceeding with deployment."
fi

# 5. Lưu SBOM như artifact (để audit)
echo "SBOM saved to $SBOM_DIR/sbom.json"
```

---

## Tham khảo

- [syft GitHub](https://github.com/anchore/syft)
- [SPDX Specification 2.3](https://spdx.github.io/spdx-spec/v2.3/)
- [trivy SBOM Scanning](https://aquasecurity.github.io/trivy/latest/docs/target/sbom/)
- [CISA SBOM Minimum Elements](https://www.cisa.gov/resources-tools/resources/software-bill-materials-sbom)
- [grype (alternative vulnerability scanner)](https://github.com/anchore/grype)
