# Giải pháp – Lab 4.3 Secret Volume Mount

## Bước 1: Xem pod insecure-app để hiểu vấn đề

```bash
kubectl describe pod insecure-app -n secret-lab
```

Output (chú ý phần Environment):
```
Environment:
  DB_USERNAME:  <set to the key 'username' in secret 'app-credentials'>  Optional: false
  DB_PASSWORD:  <set to the key 'password' in secret 'app-credentials'>  Optional: false
  API_KEY:      <set to the key 'api-key' in secret 'app-credentials'>   Optional: false
```

Vấn đề: Tên env var lộ ra, và trong một số trường hợp giá trị cũng có thể bị lộ qua log.

## Bước 2: Tạo pod secure-app với Secret volume mount

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: secret-lab
  labels:
    app: secure-app
    lab: "4.3"
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: credentials
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: app-credentials
      defaultMode: 0400
EOF
```

**Giải thích:**
- `volumeMounts.mountPath: /etc/secrets`: Secret được mount vào thư mục này trong container
- `volumeMounts.readOnly: true`: Container không thể ghi vào thư mục này
- `volumes.secret.secretName: app-credentials`: Tên Secret trong Kubernetes
- `volumes.secret.defaultMode: 0400`: Permission octal — chỉ owner đọc được (r--------)

## Bước 3: Xác minh Secret được mount đúng cách

```bash
# Kiểm tra pod đang Running
kubectl get pod secure-app -n secret-lab
# NAME         READY   STATUS    RESTARTS   AGE
# secure-app   1/1     Running   0          30s

# Xem file trong container
kubectl exec secure-app -n secret-lab -- ls -la /etc/secrets/
# total 0
# drwxrwxrwt 3 root root  120 Jan  1 00:00 .
# drwxr-xr-x 1 root root 4096 Jan  1 00:00 ..
# drwxr-xr-x 2 root root   80 Jan  1 00:00 ..2024_01_01_00_00_00.000000000
# lrwxrwxrwx 1 root root   31 Jan  1 00:00 ..data -> ..2024_01_01_00_00_00.000000000
# lrwxrwxrwx 1 root root   15 Jan  1 00:00 api-key -> ..data/api-key
# lrwxrwxrwx 1 root root   15 Jan  1 00:00 password -> ..data/password
# lrwxrwxrwx 1 root root   15 Jan  1 00:00 username -> ..data/username

# Đọc nội dung Secret
kubectl exec secure-app -n secret-lab -- cat /etc/secrets/username
# dbadmin

kubectl exec secure-app -n secret-lab -- cat /etc/secrets/password
# S3cr3tP@ssw0rd!

# Xác minh permission file
kubectl exec secure-app -n secret-lab -- stat /etc/secrets/..data/username
# File: /etc/secrets/..data/username
# Access: (0400/-r--------)  Uid: (    0/    root)   Gid: (    0/    root)
```

## Bước 4: So sánh với pod insecure-app

```bash
# Pod insecure-app: Secret lộ qua describe
kubectl describe pod insecure-app -n secret-lab | grep -A5 "Environment:"
# Environment:
#   DB_USERNAME:  <set to the key 'username' in secret 'app-credentials'>

# Pod secure-app: Không có env var
kubectl describe pod secure-app -n secret-lab | grep -A5 "Environment:"
# Environment:  <none>

# Pod secure-app: Secret được mount dưới dạng volume
kubectl describe pod secure-app -n secret-lab | grep -A5 "Mounts:"
# Mounts:
#   /etc/secrets from credentials (ro)
```

## Bước 5: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] Pod 'secure-app' tồn tại trong namespace 'secret-lab' và đang Running
[PASS] Pod 'secure-app' mount Secret 'app-credentials' dưới dạng volume
[PASS] Volume mount có defaultMode: 0400 (256 decimal) — chỉ owner đọc được
---
Kết quả: 3/3 tiêu chí đạt
```

## Pod YAML đầy đủ với best practices

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: secret-lab
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: credentials
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: app-credentials
      defaultMode: 0400
```

## Tóm tắt so sánh

| Tiêu chí | Env Var | Volume Mount |
|----------|---------|--------------|
| `kubectl describe pod` | Lộ tên env var | Chỉ hiển thị mountPath |
| Permission | Không kiểm soát được | `defaultMode: 0400` |
| Auto-rotation | Không (cần restart) | Có (tự động ~1-2 phút) |
| Child process | Kế thừa | Không kế thừa |
| Khuyến nghị CKS | Không | Có |
