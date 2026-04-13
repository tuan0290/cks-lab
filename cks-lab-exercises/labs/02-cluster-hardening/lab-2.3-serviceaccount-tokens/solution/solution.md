# Giải pháp mẫu – Lab 2.3: ServiceAccount Token Automount

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## Bước 1: Vô hiệu hóa automount trên ServiceAccount

Dùng `kubectl patch` để set `automountServiceAccountToken: false` trên ServiceAccount `web-sa`:

```bash
kubectl patch serviceaccount web-sa -n token-lab \
  -p '{"automountServiceAccountToken": false}'
```

Xác minh:

```bash
kubectl get serviceaccount web-sa -n token-lab -o yaml
# Kết quả mong đợi:
# automountServiceAccountToken: false
```

---

## Bước 2: Vô hiệu hóa automount trên pod

Pod spec là immutable — không thể patch trực tiếp. Cần xóa và tạo lại:

```bash
# Xóa pod hiện tại
kubectl delete pod web-app -n token-lab
```

Tạo lại pod với `automountServiceAccountToken: false`:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: web-app
  namespace: token-lab
  labels:
    lab: "2.3"
    app: web-app
spec:
  serviceAccountName: web-sa
  automountServiceAccountToken: false
  containers:
  - name: web-app
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF
```

Chờ pod Running:

```bash
kubectl wait --for=condition=Ready pod/web-app -n token-lab --timeout=60s
```

---

## Bước 3: Xác minh token không được mount

```bash
# Kiểm tra thư mục secrets — phải báo lỗi
kubectl exec web-app -n token-lab -- \
  ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
# Kết quả mong đợi:
# ls: /var/run/secrets/kubernetes.io/serviceaccount/: No such file or directory

# Kiểm tra trực tiếp file token
kubectl exec web-app -n token-lab -- \
  test -f /var/run/secrets/kubernetes.io/serviceaccount/token \
  && echo "Token tồn tại" || echo "Token không tồn tại"
# Kết quả mong đợi: Token không tồn tại

# Xác minh qua pod spec
kubectl get pod web-app -n token-lab \
  -o jsonpath='{.spec.automountServiceAccountToken}'
# Kết quả mong đợi: false
```

---

## Khi nào nên tắt automount?

| Trường hợp | Nên tắt? | Lý do |
|------------|----------|-------|
| Web server / API gateway | Có | Không cần giao tiếp với Kubernetes API |
| Worker / batch job | Có | Thường không cần API access |
| Operator / controller | Không | Cần watch/update resources |
| Service mesh sidecar | Không | Cần API để lấy config |
| Pod dùng Downward API | Không | Cần API để lấy metadata |

---

## Tóm tắt lệnh

```bash
# 1. Tắt automount trên ServiceAccount
kubectl patch serviceaccount web-sa -n token-lab \
  -p '{"automountServiceAccountToken": false}'

# 2. Xóa pod cũ
kubectl delete pod web-app -n token-lab

# 3. Tạo lại pod với automount tắt
kubectl run web-app -n token-lab \
  --image=nginx:alpine \
  --overrides='{"spec":{"serviceAccountName":"web-sa","automountServiceAccountToken":false}}'

# 4. Xác minh
kubectl exec web-app -n token-lab -- \
  test -f /var/run/secrets/kubernetes.io/serviceaccount/token \
  && echo "FAIL: token vẫn tồn tại" || echo "PASS: token không tồn tại"
```

---

## Tham khảo

- [Configure Service Accounts – Opt out of API credential automounting](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#opt-out-of-api-credential-automounting)
- [ServiceAccount API Reference](https://kubernetes.io/docs/reference/kubernetes-api/authentication-resources/service-account-v1/)
