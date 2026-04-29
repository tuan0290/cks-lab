#!/bin/bash
# Feature: cks-lab-exercises, Property 2: All required scripts must exist and be executable
# Feature: cks-labs-coverage-expansion, Property 1: Test scripts auto-discover all lab directories

PASS=0
FAIL=0
FAILED=0
MIN_LABS=25

echo "=========================================="
echo " Property Test 2: Lab Scripts Existence"
echo "=========================================="
echo ""

REQUIRED_SCRIPTS=("setup.sh" "cleanup.sh" "verify.sh")

# Find all lab directories (depth 2 under labs/)
LAB_DIRS=$(find labs/ -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort)

if [ -z "$LAB_DIRS" ]; then
  echo "[ERROR] Không tìm thấy thư mục lab nào trong labs/"
  echo "        Chạy script này từ thư mục gốc cks-lab-exercises/"
  exit 1
fi

for lab_dir in $LAB_DIRS; do
  lab_fail=0
  messages=()

  for script in "${REQUIRED_SCRIPTS[@]}"; do
    script_path="$lab_dir/$script"

    if [ ! -f "$script_path" ]; then
      messages+=("  Thiếu file: $script_path")
      lab_fail=1
    elif [ ! -x "$script_path" ]; then
      messages+=("  Không có quyền thực thi: $script_path")
      lab_fail=1
    fi
  done

  # Check verify.sh contains [PASS] and [FAIL] patterns
  verify_path="$lab_dir/verify.sh"
  if [ -f "$verify_path" ]; then
    if ! grep -q '\[PASS\]' "$verify_path"; then
      messages+=("  verify.sh thiếu pattern [PASS]")
      lab_fail=1
    fi
    if ! grep -q '\[FAIL\]' "$verify_path"; then
      messages+=("  verify.sh thiếu pattern [FAIL]")
      lab_fail=1
    fi
  fi

  if [ "$lab_fail" -eq 0 ]; then
    echo "[PASS] $lab_dir"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $lab_dir"
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
echo " Kết quả: ${PASS}/${TOTAL} lab directories passed"
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
  echo "Một số lab directory thiếu script hoặc script không có quyền thực thi."
  exit 1
else
  echo ""
  echo "Tất cả lab directories đạt chuẩn!"
  exit 0
fi
