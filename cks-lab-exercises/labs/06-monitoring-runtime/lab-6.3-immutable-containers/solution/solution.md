# Giải pháp – Lab 6.3 Immutable Containers

## Bước 1: Xem pod mutable-app hiện tại

```bash
# Xem cấu hình pod
kubectl get pod mutable-app -n immutable-lab -o yaml
```

Nhận thấy: không có `readOnlyRootFilesystem` trong securityContext → container có thể ghi vào bất kỳ đâu.

```bash
# Thử ghi vào filesystem (sẽ thành công)
kubectl exec mutable-app -n immutable-lab -- sh -c "echo 'test' > /etc/test.txt && echo 'Ghi thành công'"
# Output: Ghi thành công

# Dọn dẹp
kubectl exec mutable-app -n immutable-lab -- rm /etc/test.txt
```

## Bước 2: Tạo pod immutable-app

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: immutable-app
  namespace: immutable-lab
  labels:
    app: immutable-app
    lab: "6.3"
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      runAsNonRoot: false
    volumeMounts:
    - name: tmp-dir
      mountPath: /tmp
    - name: run-dir
      mountPath: /var/run
    - name: cache-dir
      mountPath: /var/cache/nginx
  volumes:
  - name: tmp-dir
    emptyDir: {}
  - name: run-dir
    emptyDir: {}
  - name: cache-dir
    emptyDir: {}
EOF
```

**Lưu ý:** nginx cần ghi vào `/var/cache/nginx` ngoài `/tmp` và `/var/run`. Nếu không mount emptyDir cho thư mục này, nginx sẽ fail.

## Bước 3: Chờ pod sẵn sàng

```bash
kubectl wait --for=condition=Ready pod/immutable-app -n immutable-lab --timeout=60s

# Xác minh pod đang Running
kubectl get pod immutable-app -n immutable-lab
```

Output mong đợi:
```
NAME            READY   STATUS    RESTARTS   AGE
immutable-app   1/1     Running   0          30s
```

## Bước 4: Xác minh immutable container

```bash
# Thử ghi vào /tmp (phải thành công vì có emptyDir)
kubectl exec immutable-app -n immutable-lab -- sh -c "echo 'test' > /tmp/test.txt && echo 'Ghi /tmp thành công'"
# Output: Ghi /tmp thành công

# Thử ghi vào /etc (phải thất bại)
kubectl exec immutable-app -n immutable-lab -- sh -c "echo 'test' > /etc/test.txt" 2>&1
# Output: sh: can't create /etc/test.txt: Read-only file system

# Thử ghi vào /usr (phải thất bại)
kubectl exec immutable-app -n immutable-lab -- sh -c "echo 'test' > /usr/test.txt" 2>&1
# Output: sh: can't create /usr/test.txt: Read-only file system
```

## Bước 5: Kiểm tra cấu hình bằng kubectl

```bash
# Kiểm tra readOnlyRootFilesystem
kubectl get pod immutable-app -n immutable-lab \
  -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'
# Output: true

# Kiểm tra volume mounts
kubectl get pod immutable-app -n immutable-lab \
  -o jsonpath='{range .spec.containers[0].volumeMounts[*]}{.mountPath}{"\n"}{end}'
# Output:
# /tmp
# /var/run
# /var/cache/nginx
```

## Bước 6: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] Pod 'immutable-app' có readOnlyRootFilesystem: true
[PASS] Pod 'immutable-app' có emptyDir volume mounts cho /tmp và /var/run
[PASS] Pod 'immutable-app' đang ở trạng thái Running
---
Kết quả: 3/3 tiêu chí đạt
```

## Pod YAML đầy đủ với best practices

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-app
  namespace: immutable-lab
  labels:
    app: immutable-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101        # nginx user trong alpine image
    runAsGroup: 101
    fsGroup: 101
  containers:
  - name: app
    image: nginx:1.25-alpine
    ports:
    - containerPort: 8080  # Non-root port
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp-dir
      mountPath: /tmp
    - name: run-dir
      mountPath: /var/run
    - name: cache-dir
      mountPath: /var/cache/nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  volumes:
  - name: tmp-dir
    emptyDir:
      sizeLimit: 50Mi
  - name: run-dir
    emptyDir:
      sizeLimit: 10Mi
  - name: cache-dir
    emptyDir:
      sizeLimit: 100Mi
```

## So sánh mutable vs immutable

| Thuộc tính | mutable-app | immutable-app |
|-----------|-------------|---------------|
| `readOnlyRootFilesystem` | false (mặc định) | true |
| Ghi vào /etc | Được | Bị từ chối |
| Ghi vào /tmp | Được | Được (emptyDir) |
| Ghi vào /var/run | Được | Được (emptyDir) |
| Rủi ro malware | Cao | Thấp |
| Tính toàn vẹn | Không đảm bảo | Đảm bảo |

## Xử lý lỗi phổ biến

### Pod bị CrashLoopBackOff

```bash
kubectl logs immutable-app -n immutable-lab
```

Nếu thấy lỗi `Read-only file system` cho một thư mục, thêm emptyDir mount cho thư mục đó:

```yaml
# Ví dụ: nginx cần /var/log/nginx
volumeMounts:
- name: log-dir
  mountPath: /var/log/nginx
volumes:
- name: log-dir
  emptyDir: {}
```

### Tìm tất cả thư mục cần ghi của một image

```bash
# Chạy container tạm thời để kiểm tra
docker run --rm nginx:1.25-alpine sh -c "find / -writable -type d 2>/dev/null | grep -v proc | grep -v sys"
```
