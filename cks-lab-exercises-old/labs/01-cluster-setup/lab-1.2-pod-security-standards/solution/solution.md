# Giải pháp mẫu – Lab 1.2: Pod Security Standards (PSS)

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành.

---

## Bước 1: Gắn PSS restricted lên namespace

```bash
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

---

## Bước 2: Quan sát lỗi khi pod thiếu SecurityContext

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: pss-lab
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
```

Output — PSS liệt kê từng vi phạm:
```
pods "bad-pod" is forbidden: violates PodSecurity "restricted:latest":
  allowPrivilegeEscalation != false (container "app" must set securityContext.allowPrivilegeEscalation=false),
  unrestricted capabilities (container "app" must set securityContext.capabilities.drop=["ALL"]),
  runAsNonRoot != true (pod or container "app" must set securityContext.runAsNonRoot=true),
  seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

---

## Bước 3: Pod hợp lệ — đủ tất cả yêu cầu PSS restricted

```bash
kubectl apply -f - <<EOF
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
      type: RuntimeDefault    # Seccomp: lọc syscall nguy hiểm
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false   # Không leo thang đặc quyền
      readOnlyRootFilesystem: true      # Filesystem chỉ đọc
      capabilities:
        drop: [ALL]                     # Drop tất cả Linux capabilities
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
EOF
```

---

## Bước 4: Xác minh Seccomp và Capabilities

```bash
# Xem seccompProfile
kubectl get pod compliant-pod -n pss-lab \
  -o jsonpath='{.spec.securityContext.seccompProfile}'
# Output: {"type":"RuntimeDefault"}

# Xem capabilities
kubectl get pod compliant-pod -n pss-lab \
  -o jsonpath='{.spec.containers[0].securityContext.capabilities}'
# Output: {"drop":["ALL"]}
```

---

## Bước 5: Thử add capability — bị từ chối

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cap-test
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
      capabilities:
        drop: [ALL]
        add: [NET_ADMIN]    # Vi phạm PSS restricted
EOF
```

Lỗi: `unrestricted capabilities (container "app" must not include "NET_ADMIN" in securityContext.capabilities.add)`

> PSS restricted chỉ cho phép add `NET_BIND_SERVICE`. Tất cả capability khác đều bị cấm.

---

## Bước 6: Sửa PSS level — thay đổi label

```bash
# Hạ xuống baseline
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce=baseline \
  --overwrite

# Nâng lại restricted
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce=restricted \
  --overwrite

# Xóa label (tắt PSS)
kubectl label namespace pss-lab pod-security.kubernetes.io/enforce-
```

---

## Giải thích từng yêu cầu PSS restricted

### `runAsNonRoot: true`
Container chạy với UID 0 (root) có thể escape ra host với quyền root nếu có lỗ hổng container runtime.

### `allowPrivilegeEscalation: false`
Ngăn process con có thêm quyền hơn process cha thông qua setuid/setgid binary (ví dụ: `sudo`, `su`).

### `capabilities.drop: [ALL]`
Container mặc định có ~14 Linux capabilities. Một số nguy hiểm:
- `CAP_NET_RAW` → sniff network traffic
- `CAP_SYS_ADMIN` → gần như toàn quyền hệ thống
- `CAP_CHOWN` → chiếm quyền sở hữu file

`drop: [ALL]` loại bỏ tất cả, áp dụng nguyên tắc least privilege ở tầng kernel.

### `seccompProfile: RuntimeDefault`
Container chia sẻ kernel với host. Seccomp lọc syscall nguy hiểm (reboot, kexec_load, ptrace...) ngăn khai thác lỗ hổng kernel để escape container.

`RuntimeDefault` là profile mặc định của container runtime — chặn ~100 syscall nguy hiểm nhất mà không ảnh hưởng ứng dụng thông thường.

---

## Tóm tắt: Checklist pod tuân thủ PSS restricted

```yaml
spec:
  securityContext:
    runAsNonRoot: true          # ✅ Không chạy root
    runAsUser: 1000             # ✅ UID cụ thể
    seccompProfile:
      type: RuntimeDefault      # ✅ Seccomp profile
  containers:
  - securityContext:
      allowPrivilegeEscalation: false  # ✅ Không leo thang đặc quyền
      readOnlyRootFilesystem: true     # ✅ Filesystem chỉ đọc (khuyến nghị)
      capabilities:
        drop: [ALL]                    # ✅ Drop tất cả capabilities
```

---

## Tham khảo

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Kubernetes Seccomp](https://kubernetes.io/docs/tutorials/security/seccomp/)
