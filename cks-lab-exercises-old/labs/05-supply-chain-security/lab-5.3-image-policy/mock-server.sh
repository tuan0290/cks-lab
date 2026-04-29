#!/bin/bash
# Lab 5.3 – Mock ImagePolicyWebhook Server
# Giả lập external webhook service tại https://localhost:1234
#
# Server nhận ImageReview request từ kube-apiserver và trả về Allow/Deny
# dựa trên danh sách allowed registries.
#
# Sử dụng:
#   bash mock-server.sh          # chạy server (foreground)
#   bash mock-server.sh start    # chạy background
#   bash mock-server.sh stop     # dừng server
#   bash mock-server.sh status   # kiểm tra trạng thái

POLICY_DIR="/etc/kubernetes/policywebhook"
CERT="$POLICY_DIR/external-cert.pem"
KEY="$POLICY_DIR/external-key.pem"
PORT=1234
PID_FILE="/tmp/mock-image-policy-server.pid"
LOG_FILE="/tmp/mock-image-policy-server.log"

# Danh sách registry được phép
ALLOWED_REGISTRIES=(
  "registry.k8s.io"
  "docker.io/library"
)

# --- Kiểm tra prerequisites ---

check_prereqs() {
  if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
    echo "[ERROR] Không tìm thấy cert/key tại $POLICY_DIR"
    echo "        Chạy setup.sh trước: bash setup.sh"
    exit 1
  fi

  if ! command -v python3 &>/dev/null; then
    echo "[ERROR] python3 không tìm thấy. Vui lòng cài đặt python3."
    exit 1
  fi
}

# --- Tạo Python server script ---

create_server_script() {
  cat > /tmp/mock_image_policy_server.py <<'PYEOF'
#!/usr/bin/env python3
"""
Mock ImagePolicyWebhook server cho Kubernetes Lab 5.3
Lắng nghe HTTPS tại localhost:1234
Nhận ImageReview request, kiểm tra image prefix, trả về Allow/Deny
"""

import json
import ssl
import sys
import os
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)

# Đọc allowed registries từ env hoặc dùng default
ALLOWED = os.environ.get(
    "ALLOWED_REGISTRIES",
    "registry.k8s.io,docker.io/library"
).split(",")

log.info(f"Allowed registries: {ALLOWED}")


def is_allowed(image: str) -> bool:
    for prefix in ALLOWED:
        if image.startswith(prefix.strip()):
            return True
    return False


class ImagePolicyHandler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        # Override để dùng logging thay vì print
        log.info(f"{self.address_string()} - {format % args}")

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            review = json.loads(body)

            # Lấy danh sách containers từ ImageReview spec
            containers = review.get("spec", {}).get("containers", [])
            images = [c.get("image", "") for c in containers]

            # Kiểm tra từng image
            denied_images = [img for img in images if not is_allowed(img)]
            allowed = len(denied_images) == 0

            if allowed:
                log.info(f"ALLOW — images: {images}")
                reason = ""
            else:
                log.warning(f"DENY  — images not allowed: {denied_images}")
                reason = f"Images not from allowed registries: {denied_images}. Allowed: {ALLOWED}"

            response = {
                "apiVersion": "imagepolicy.k8s.io/v1alpha1",
                "kind": "ImageReview",
                "status": {
                    "allowed": allowed,
                    "reason": reason
                }
            }

            response_body = json.dumps(response).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(response_body)))
            self.end_headers()
            self.wfile.write(response_body)

        except Exception as e:
            log.error(f"Error processing request: {e}")
            self.send_response(500)
            self.end_headers()


def main():
    cert = sys.argv[1]
    key  = sys.argv[2]
    port = int(sys.argv[3]) if len(sys.argv) > 3 else 1234

    server = HTTPServer(("127.0.0.1", port), ImagePolicyHandler)

    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile=cert, keyfile=key)
    server.socket = ctx.wrap_socket(server.socket, server_side=True)

    log.info(f"Mock ImagePolicyWebhook server listening on https://localhost:{port}")
    log.info(f"Allowed registries: {ALLOWED}")
    log.info("Press Ctrl+C to stop")
    server.serve_forever()


if __name__ == "__main__":
    main()
PYEOF
}

# --- Actions ---

start_server() {
  check_prereqs
  create_server_script

  if [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
    echo "[WARN] Server đã đang chạy (PID: $(cat $PID_FILE))"
    echo "       Dùng 'bash mock-server.sh stop' để dừng trước."
    exit 0
  fi

  ALLOWED_REGISTRIES_ENV=$(IFS=,; echo "${ALLOWED_REGISTRIES[*]}")

  echo "Khởi động mock ImagePolicyWebhook server..."
  echo "  Port:    $PORT"
  echo "  Cert:    $CERT"
  echo "  Log:     $LOG_FILE"
  echo "  Allowed: ${ALLOWED_REGISTRIES[*]}"
  echo ""

  ALLOWED_REGISTRIES="$ALLOWED_REGISTRIES_ENV" \
    python3 /tmp/mock_image_policy_server.py "$CERT" "$KEY" "$PORT" \
    > "$LOG_FILE" 2>&1 &

  echo $! > "$PID_FILE"
  sleep 1

  if kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
    echo "[OK] Server đang chạy (PID: $(cat $PID_FILE))"
    echo ""
    echo "Test server:"
    echo "  kubectl run allowed-pod --image=docker.io/library/nginx:alpine --restart=Never"
    echo "  kubectl run denied-pod  --image=gcr.io/google-containers/pause:3.1 --restart=Never"
    echo ""
    echo "Xem log: tail -f $LOG_FILE"
    echo "Dừng:    bash mock-server.sh stop"
  else
    echo "[ERROR] Server không khởi động được. Xem log: cat $LOG_FILE"
    exit 1
  fi
}

stop_server() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
    PID=$(cat "$PID_FILE")
    kill "$PID"
    rm -f "$PID_FILE"
    echo "[OK] Server đã dừng (PID: $PID)"
  else
    echo "[SKIP] Server không đang chạy."
    rm -f "$PID_FILE"
  fi
}

status_server() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
    echo "[RUNNING] Mock server đang chạy (PID: $(cat $PID_FILE))"
    echo "          Log: $LOG_FILE"
    echo ""
    echo "--- 10 dòng log gần nhất ---"
    tail -10 "$LOG_FILE" 2>/dev/null || echo "(chưa có log)"
  else
    echo "[STOPPED] Mock server không đang chạy."
  fi
}

run_foreground() {
  check_prereqs
  create_server_script

  ALLOWED_REGISTRIES_ENV=$(IFS=,; echo "${ALLOWED_REGISTRIES[*]}")

  echo "=========================================="
  echo " Mock ImagePolicyWebhook Server"
  echo "=========================================="
  echo "  Port:    https://localhost:$PORT"
  echo "  Allowed: ${ALLOWED_REGISTRIES[*]}"
  echo "  Ctrl+C để dừng"
  echo "=========================================="
  echo ""

  ALLOWED_REGISTRIES="$ALLOWED_REGISTRIES_ENV" \
    python3 /tmp/mock_image_policy_server.py "$CERT" "$KEY" "$PORT"
}

# --- Main ---

case "${1:-}" in
  start)
    start_server
    ;;
  stop)
    stop_server
    ;;
  status)
    status_server
    ;;
  *)
    run_foreground
    ;;
esac
