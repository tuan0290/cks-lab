# Giải pháp mẫu – Lab 1.2: Pod Security Standards (PSS)

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## Bước 1: Gắn nhãn PSS restricted lên namespace `pss-lab`

```bash
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

Xác nhận:

```bash
kubectl get namespace pss-lab --show-labels
```

Output mong đợi:
```
NAME      STATUS   AGE   LABELS
pss-lab   Active   5m    ...,pod-security.kubernetes.io/enforce=restricted,pod-security.kubernetes.io/enforce-version=latest,...
```

---

## Bước 2: Pod vi phạm bị từ chối

Thử tạo pod với `privileged: true`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: pss-lab
spec:
  containers:
  - name: nginx
    image: nginx:1.25-alpine
    securityContext:
      privileged: true
```

```bash
kubectl apply -f privileged-pod.yaml
```

Output mong đợi (pod bị từ chối):
```
Error from server (Forbidden): error when creating "privileged-pod.yaml":
pods "privileged-pod" is forbidden: violates PodSecurity "restricted:latest":
privileged (container "nginx" must not set securityContext.privileged=true),
allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false),
unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]),
runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true),
seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

---

## Giải thích các mức PSS

### Privileged

Không có hạn chế nào. Cho phép tất cả các cấu hình, kể cả container chạy với quyền root đầy đủ.

```bash
# Namespace không có PSS hoặc PSS privileged
kubectl label namespace my-ns pod-security.kubernetes.io/enforce=privileged
```

Dùng cho: CNI plugins, storage drivers, các workload hệ thống cần quyền đặc biệt.

---

### Baseline

Ngăn chặn các leo thang đặc quyền rõ ràng. Cấm:
- `privileged: true`
- `hostPID: true`, `hostIPC: true`, `hostNetwork: true`
- `hostPath` volumes
- Một số Linux capabilities nguy hiểm (NET_ADMIN, SYS_ADMIN, v.v.)

```bash
kubectl label namespace my-ns pod-security.kubernetes.io/enforce=baseline
```

Dùng cho: Workload thông thường không cần quyền đặc biệt.

---

### Restricted

Tuân thủ đầy đủ best practices bảo mật container. Yêu cầu:
- `privileged: false` (hoặc không set)
- `allowPrivilegeEscalation: false`
- `runAsNonRoot: true`
- `capabilities.drop: ["ALL"]`
- `seccompProfile.type: RuntimeDefault` hoặc `Localhost`
- Không dùng `hostPath`, `hostPID`, `hostIPC`, `hostNetwork`

```bash
kubectl label namespace my-ns pod-security.kubernetes.io/enforce=restricted
```

Dùng cho: Workload production nhạy cảm, ứng dụng xử lý dữ liệu quan trọng.

---

## Pod tuân thủ PSS restricted

Đây là ví dụ pod hợp lệ với PSS restricted:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: pss-lab
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
```

---

## Ba chế độ PSS

Ngoài `enforce`, PSS còn có hai chế độ khác:

```bash
# enforce: từ chối pod vi phạm
kubectl label namespace my-ns pod-security.kubernetes.io/enforce=restricted

# audit: ghi log vi phạm, không từ chối
kubectl label namespace my-ns pod-security.kubernetes.io/audit=restricted

# warn: hiển thị cảnh báo, không từ chối
kubectl label namespace my-ns pod-security.kubernetes.io/warn=restricted
```

Có thể kết hợp cả ba chế độ với các mức khác nhau:

```bash
kubectl label namespace my-ns \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

Cấu hình này: enforce baseline (từ chối vi phạm baseline), nhưng audit và warn ở mức restricted để chuẩn bị nâng cấp lên restricted.

---

## Tham khảo

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Enforce Pod Security Standards with Namespace Labels](https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/)
