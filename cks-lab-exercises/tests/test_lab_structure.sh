#!/bin/bash
# Feature: cks-lab-exercises, Property 1: Lab README must contain all required sections
# Feature: cks-labs-coverage-expansion, Property 1: Test scripts auto-discover all lab directories

PASS=0
FAIL=0
FAILED=0
MIN_LABS=25

echo "=========================================="
echo " Property Test 1: Lab README Structure"
echo "=========================================="
echo ""

REQUIRED_SECTIONS=(
  "## Mục tiêu"
  "## Bối cảnh"
  "## Yêu cầu môi trường"
  "## Các bước thực hiện"
  "## Tiêu chí kiểm tra"
  "## Gợi ý"
  "## Giải pháp mẫu"
  "## Giải thích"
)

# Find all lab READMEs (exclude root README and mock-exam READMEs)
READMES=$(find labs/ -name "README.md" 2>/dev/null | sort)

if [ -z "$READMES" ]; then
  echo "[ERROR] Không tìm thấy README.md nào trong thư mục labs/"
  echo "        Chạy script này từ thư mục gốc cks-lab-exercises/"
  exit 1
fi

for readme in $READMES; do
  readme_fail=0
  messages=()

  # Check all required sections
  for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "$section" "$readme"; then
      messages+=("  Thiếu section: $section")
      readme_fail=1
    fi
  done

  # Check estimated time is between 10-30 minutes
  time_val=$(grep -oE 'Thời gian ước tính.*[0-9]+' "$readme" | grep -oE '[0-9]+' | head -1)
  if [ -z "$time_val" ]; then
    messages+=("  Thiếu trường 'Thời gian ước tính'")
    readme_fail=1
  elif [ "$time_val" -lt 10 ] || [ "$time_val" -gt 30 ]; then
    messages+=("  Thời gian ước tính không hợp lệ: ${time_val} phút (phải 10-30)")
    readme_fail=1
  fi

  if [ "$readme_fail" -eq 0 ]; then
    echo "[PASS] $readme"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $readme"
    for msg in "${messages[@]}"; do
      echo "$msg"
    done
    FAIL=$((FAIL + 1))
    FAILED=1
  fi
done

echo ""
TOTAL=$((PASS + FAIL))
echo "=========================================="
echo " Kết quả: ${PASS}/${TOTAL} READMEs passed"
echo " Checked ${TOTAL} labs"
echo "=========================================="

# Smoke test: tổng số lab phải >= MIN_LABS
if [ "$TOTAL" -lt "$MIN_LABS" ]; then
  echo ""
  echo "[FAIL] Expected at least ${MIN_LABS} labs, found ${TOTAL}"
  FAILED=1
else
  echo "[PASS] Lab count: ${TOTAL} >= ${MIN_LABS} (minimum required)"
fi

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "Một số README không đạt cấu trúc chuẩn."
  exit 1
else
  echo ""
  echo "Tất cả README đạt cấu trúc chuẩn!"
  exit 0
fi
