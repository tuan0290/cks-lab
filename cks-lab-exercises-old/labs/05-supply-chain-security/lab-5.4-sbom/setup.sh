#!/bin/bash
# Lab 5.4 – SBOM (Software Bill of Materials)
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 5.4 – SBOM với syft và trivy"
echo " Đang khởi tạo môi trường..."
echo "=========================================="
echo ""

# --- Kiểm tra prerequisites ---

MISSING_TOOLS=0

if command -v syft &>/dev/null; then
  SYFT_VERSION=$(syft version 2>/dev/null | head -1 || echo "unknown")
  echo "[OK] syft đã được cài đặt: $SYFT_VERSION"
else
  echo "[WARN] syft chưa được cài đặt."
  echo "       Cài đặt: curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin"
  MISSING_TOOLS=1
fi

if command -v trivy &>/dev/null; then
  TRIVY_VERSION=$(trivy --version 2>/dev/null | head -1 || echo "unknown")
  echo "[OK] trivy đã được cài đặt: $TRIVY_VERSION"
else
  echo "[WARN] trivy chưa được cài đặt."
  echo "       Cài đặt: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
  MISSING_TOOLS=1
fi

if [ "$MISSING_TOOLS" -eq 1 ]; then
  echo ""
  echo "[WARN] Một số công cụ chưa được cài đặt."
  echo "       Vui lòng cài đặt các công cụ trên trước khi tiếp tục."
  echo ""
fi

# --- Tạo thư mục kết quả ---

echo ""
echo "Tạo thư mục /tmp/sbom-results/..."

mkdir -p /tmp/sbom-results
echo "[OK] Thư mục /tmp/sbom-results/ đã được tạo."

# --- Kiểm tra Docker/containerd (để pull image) ---

if command -v docker &>/dev/null; then
  echo "[OK] Docker đã được cài đặt — syft có thể pull image trực tiếp."
elif command -v crictl &>/dev/null; then
  echo "[OK] crictl đã được cài đặt."
else
  echo "[INFO] Không tìm thấy Docker. syft sẽ pull image qua registry API."
fi

# --- Tóm tắt ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Thư mục kết quả: /tmp/sbom-results/"
echo ""
echo "Bước tiếp theo:"
echo "  1. Đọc README.md để hiểu yêu cầu bài lab"
echo "  2. Tạo SBOM cho nginx:1.25-alpine:"
echo "     syft nginx:1.25-alpine -o spdx-json=/tmp/sbom-results/nginx-sbom.json"
echo "  3. Quét SBOM tìm lỗ hổng:"
echo "     trivy sbom /tmp/sbom-results/nginx-sbom.json --output /tmp/sbom-results/vuln-report.txt"
echo "  4. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
