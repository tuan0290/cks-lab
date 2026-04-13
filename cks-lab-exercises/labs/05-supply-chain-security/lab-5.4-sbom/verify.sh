#!/bin/bash
# Lab 5.4 – SBOM (Software Bill of Materials)
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 5.4 – Kiểm tra kết quả"
echo "=========================================="
echo ""

# --- Hàm tiện ích ---

pass() {
  echo "[PASS] $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "[FAIL] $1"
  if [ -n "$2" ]; then
    echo "       Gợi ý: $2"
  fi
  FAIL=$((FAIL + 1))
  FAILED=1
}

# --- Tiêu chí 1: File nginx-sbom.json tồn tại và là SBOM hợp lệ ---

echo "Kiểm tra tiêu chí 1: /tmp/sbom-results/nginx-sbom.json tồn tại và hợp lệ"

SBOM_FILE="/tmp/sbom-results/nginx-sbom.json"

if [ ! -f "$SBOM_FILE" ]; then
  fail "File $SBOM_FILE không tồn tại" \
       "Chạy: syft nginx:1.25-alpine -o spdx-json=$SBOM_FILE"
else
  # Kiểm tra file không rỗng
  if [ ! -s "$SBOM_FILE" ]; then
    fail "File $SBOM_FILE tồn tại nhưng rỗng" \
         "Chạy lại: syft nginx:1.25-alpine -o spdx-json=$SBOM_FILE"
  else
    # Kiểm tra là JSON hợp lệ
    if ! python3 -m json.tool "$SBOM_FILE" &>/dev/null 2>&1; then
      fail "File $SBOM_FILE không phải JSON hợp lệ" \
           "Đảm bảo dùng định dạng spdx-json: syft nginx:1.25-alpine -o spdx-json=$SBOM_FILE"
    else
      # Kiểm tra chứa spdxVersion hoặc SPDXID (dấu hiệu SBOM hợp lệ)
      if python3 -c "
import json, sys
with open('$SBOM_FILE') as f:
    d = json.load(f)
has_spdx = 'spdxVersion' in d or 'SPDXID' in d
sys.exit(0 if has_spdx else 1)
" 2>/dev/null; then
        SPDX_VER=$(python3 -c "import json; d=json.load(open('$SBOM_FILE')); print(d.get('spdxVersion', 'N/A'))" 2>/dev/null)
        PKG_COUNT=$(python3 -c "import json; d=json.load(open('$SBOM_FILE')); print(len(d.get('packages', [])))" 2>/dev/null || echo "?")
        pass "SBOM hợp lệ tại $SBOM_FILE (SPDX version: $SPDX_VER, packages: $PKG_COUNT)"
      else
        fail "File $SBOM_FILE không chứa 'spdxVersion' hoặc 'SPDXID' — không phải SPDX SBOM hợp lệ" \
             "Dùng định dạng spdx-json: syft nginx:1.25-alpine -o spdx-json=$SBOM_FILE"
      fi
    fi
  fi
fi

echo ""

# --- Tiêu chí 2: File vuln-report.txt tồn tại ---

echo "Kiểm tra tiêu chí 2: /tmp/sbom-results/vuln-report.txt tồn tại"

VULN_FILE="/tmp/sbom-results/vuln-report.txt"

if [ ! -f "$VULN_FILE" ]; then
  fail "File $VULN_FILE không tồn tại" \
       "Chạy: trivy sbom $SBOM_FILE --format table --output $VULN_FILE"
else
  if [ ! -s "$VULN_FILE" ]; then
    fail "File $VULN_FILE tồn tại nhưng rỗng" \
         "Chạy lại: trivy sbom $SBOM_FILE --format table --output $VULN_FILE"
  else
    FILE_SIZE=$(wc -c < "$VULN_FILE")
    pass "Vulnerability report tồn tại tại $VULN_FILE (${FILE_SIZE} bytes)"
  fi
fi

echo ""

# --- Tiêu chí 3: SBOM chứa danh sách packages (không rỗng) ---

echo "Kiểm tra tiêu chí 3: SBOM chứa danh sách packages"

if [ -f "$SBOM_FILE" ] && python3 -m json.tool "$SBOM_FILE" &>/dev/null 2>&1; then
  PKG_COUNT=$(python3 -c "
import json
with open('$SBOM_FILE') as f:
    d = json.load(f)
packages = d.get('packages', [])
print(len(packages))
" 2>/dev/null || echo "0")

  if [ "$PKG_COUNT" -gt 0 ]; then
    pass "SBOM chứa $PKG_COUNT packages (danh sách không rỗng)"
  else
    fail "SBOM không chứa packages (danh sách rỗng)" \
         "Đảm bảo syft đã phân tích đúng image: syft nginx:1.25-alpine -o spdx-json=$SBOM_FILE"
  fi
else
  fail "Không thể kiểm tra packages — SBOM file không hợp lệ hoặc không tồn tại" \
       "Xem tiêu chí 1 để sửa lỗi SBOM file"
fi

echo ""

# --- Tóm tắt ---

TOTAL=$((PASS + FAIL))
echo "=========================================="
echo " Kết quả: ${PASS}/${TOTAL} tiêu chí đạt"
echo "=========================================="

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "Một số tiêu chí chưa đạt. Xem gợi ý ở trên và thử lại."
  echo "Tham khảo: README.md hoặc solution/solution.md"
  exit 1
else
  echo ""
  echo "Chúc mừng! Bạn đã hoàn thành Lab 5.4."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
