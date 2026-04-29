# Giải pháp – Lab 4.4 RuntimeClass Sandbox

## Bước 1: Tạo RuntimeClass gvisor

```bash
kubectl apply -f - <<EOF
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
EOF
```

Hoặc dùng file manifest đã tạo sẵn:

```bash
kubectl apply -f /tmp/gvisor-runtimeclass.yaml
```

**Giải thích:**
- `apiVersion: node.k8s.io/v1`: API version cho RuntimeClass (stable từ Kubernetes 1.20)
- `kind: RuntimeClass`: Loại resource
- `name: gvisor`: Tên RuntimeClass — được tham chiếu trong `spec.runtimeClassName` của pod
- `handler: runsc`: Tên handler trên node — phải khớp với tên được cấu hình trong containerd

## Bước 2: Xác minh RuntimeClass đã được tạo

```bash
kubectl get runtimeclass
# NAME     HANDLER   AGE
# gvisor   runsc     10s

kubectl describe runtimeclass gvisor
# Name:         gvisor
# Namespace:
# Labels:       <none>
# Annotations:  <none>
# API Version:  node.k8s.io/v1
# Handler:      runsc
# Kind:         RuntimeClass
```

## Bước 3: Tạo pod sandboxed-pod với runtimeClassName: gvisor

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-pod
  namespace: runtime-lab
  labels:
    app: sandboxed-pod
    lab: "4.4"
spec:
  runtimeClassName: gvisor
  containers:
  - name: app
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
EOF
```

**Giải thích:**
- `runtimeClassName: gvisor`: Chỉ định pod sẽ dùng RuntimeClass `gvisor`
- Kubernetes scheduler sẽ chỉ schedule pod lên node có handler `runsc` được cài đặt

## Bước 4: Xác minh cấu hình

```bash
# Kiểm tra pod
kubectl get pod sandboxed-pod -n runtime-lab

# Xác minh runtimeClassName
kubectl get pod sandboxed-pod -n runtime-lab \
  -o jsonpath='{.spec.runtimeClassName}'
# gvisor

# Xem chi tiết
kubectl describe pod sandboxed-pod -n runtime-lab
# Runtime Class Name:  gvisor
```

## Bước 5: (Nếu gVisor đã cài đặt) Xác minh sandbox isolation

```bash
# Kernel version trong gVisor container sẽ khác với host
kubectl exec sandboxed-pod -n runtime-lab -- uname -r
# 4.4.0 (gVisor kernel version — khác với host)

# So sánh với pod thông thường
kubectl run normal-pod --image=nginx:1.25-alpine --restart=Never -n runtime-lab
kubectl exec normal-pod -n runtime-lab -- uname -r
# 5.15.0-... (host kernel version)
```

## Bước 6: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] RuntimeClass 'gvisor' tồn tại với handler 'runsc'
[PASS] Pod 'sandboxed-pod' tồn tại trong namespace 'runtime-lab' và đang Running
[PASS] Pod 'sandboxed-pod' có runtimeClassName: gvisor
---
Kết quả: 3/3 tiêu chí đạt
```

## RuntimeClass với Scheduling

Có thể thêm scheduling constraints để đảm bảo pod chỉ chạy trên node có gVisor:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    runtime: gvisor          # Node phải có label này
  tolerations:
  - key: "runtime"
    operator: "Equal"
    value: "gvisor"
    effect: "NoSchedule"
```

## Cài đặt gVisor trên node (tham khảo)

```bash
# Trên Ubuntu/Debian node worker
curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" | sudo tee /etc/apt/sources.list.d/gvisor.list > /dev/null
sudo apt-get update && sudo apt-get install -y runsc

# Cấu hình containerd
sudo mkdir -p /etc/containerd
sudo tee -a /etc/containerd/config.toml <<EOF

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF

sudo systemctl restart containerd
```

## Tóm tắt các lệnh quan trọng

| Lệnh | Mục đích |
|------|----------|
| `kubectl get runtimeclass` | Liệt kê tất cả RuntimeClass |
| `kubectl describe runtimeclass gvisor` | Xem chi tiết RuntimeClass |
| `kubectl get pod -o jsonpath='{.spec.runtimeClassName}'` | Xem runtimeClassName của pod |
| `kubectl exec <pod> -- uname -r` | Kiểm tra kernel version (xác minh sandbox) |
