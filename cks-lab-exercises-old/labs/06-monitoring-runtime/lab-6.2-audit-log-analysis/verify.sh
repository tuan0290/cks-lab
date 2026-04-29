#!/bin/bash
# Lab 6.2 – Audit Log Analysis
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 6.2 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: File /tmp/answers.txt tồn tại ---

echo "Kiểm tra tiêu chí 1: File /tmp/answers.txt tồn tại"

if [ -f /tmp/answers.txt ]; then
  pass "File /tmp/answers.txt tồn tại"
else
  fail "File /tmp/answers.txt không tìm thấy" \
       "Tạo file: nano /tmp/answers.txt và ghi câu trả lời cho 3 câu hỏi"
fi

echo ""

# --- Tiêu chí 2: answers.txt chứa câu trả lời về Secret access ---

echo "Kiểm tra tiêu chí 2: /tmp/answers.txt chứa câu trả lời về user truy cập Secret"

if [ ! -f /tmp/answers.txt ]; then
  fail "Không thể kiểm tra: /tmp/answers.txt không tồn tại" ""
else
  # Câu trả lời đúng: alice đã truy cập secret
  if grep -qi "alice" /tmp/answers.txt; then
    pass "File /tmp/answers.txt chứa câu trả lời đúng về user truy cập Secret (alice)"
  else
    fail "File /tmp/answers.txt không chứa câu trả lời đúng về user truy cập Secret" \
         "Phân tích: cat /tmp/sample-audit.log | jq -r 'select(.objectRef.resource == \"secrets\") | .user.username' | sort | uniq"
  fi
fi

echo ""

# --- Tiêu chí 3: answers.txt chứa câu trả lời về 403 và exec ---

echo "Kiểm tra tiêu chí 3: /tmp/answers.txt chứa câu trả lời về request 403 và exec vào pod"

if [ ! -f /tmp/answers.txt ]; then
  fail "Không thể kiểm tra: /tmp/answers.txt không tồn tại" ""
else
  ANSWERS_OK=0

  # Kiểm tra câu trả lời về 403 (bob bị từ chối)
  if grep -qi "bob" /tmp/answers.txt || grep -qi "403" /tmp/answers.txt || grep -qi "forbidden" /tmp/answers.txt; then
    ANSWERS_OK=$((ANSWERS_OK + 1))
  fi

  # Kiểm tra câu trả lời về exec (charlie exec vào web-pod hoặc db-pod)
  if grep -qi "charlie\|web-pod\|db-pod\|exec" /tmp/answers.txt; then
    ANSWERS_OK=$((ANSWERS_OK + 1))
  fi

  if [ "$ANSWERS_OK" -ge 2 ]; then
    pass "File /tmp/answers.txt chứa câu trả lời về request 403 (bob) và exec vào pod (charlie)"
  elif [ "$ANSWERS_OK" -eq 1 ]; then
    fail "File /tmp/answers.txt chỉ chứa một phần câu trả lời (cần cả 403 và exec)" \
         "Kiểm tra: 403 request từ bob, exec vào pod bởi charlie"
  else
    fail "File /tmp/answers.txt không chứa câu trả lời về 403 và exec" \
         "Phân tích 403: jq 'select(.responseStatus.code == 403)' /tmp/sample-audit.log | Phân tích exec: jq 'select(.objectRef.subresource == \"exec\")' /tmp/sample-audit.log"
  fi
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 6.2."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
