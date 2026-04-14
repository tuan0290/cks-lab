# Lab 4.4 – RuntimeClass Sandbox

**Domain:** Minimize Microservice Vulnerabilities (20%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Tạo `RuntimeClass` với tên `gvisor` và handler `runsc` để sử dụng gVisor sandbox runtime
- Tạo pod `sandboxed-pod` trong namespace `runtime-lab` với `runtimeClassName: gvisor`
- Hiểu sự khác biệt giữa container runtime thông thường và sandbox runtime
- Xác minh pod được cấu hình đúng với RuntimeClass

---

## Lý thuyết

### Container Runtime là gì?

**Container Runtime** là phần mềm chịu trách nhiệm chạy container. Kubernetes hỗ trợ nhiều runtime thông qua **CRI (Container Runtime Interface)**:

| Runtime | Handler | Cơ chế cô lập | Overhead |
|---------|---------|--------------|---------|
| **runc** (mặc định) | `runc` | Linux namespaces + cgroups | Thấp |
| **gVisor** | `runsc` | User-space kernel | Trung bình |
| **kata-containers** | `kata` | Lightweight VM | Cao |

### Tại sao cần Sandbox Runtime?

Container thông thường (runc) chia sẻ kernel với host. Nếu có lỗ hổng kernel, container có thể escape ra host. **Sandbox runtime** cung cấp lớp cô lập bổ sung:

```
runc:  Container → Linux Kernel (shared) → Host
gVisor: Container → gVisor (user-space kernel) → Linux Kernel → Host
kata:  Container → Guest Kernel → Hypervisor → Host Kernel → Host
```

### gVisor là gì?

**gVisor** (Google) là sandbox runtime intercept system calls từ container và xử lý trong user space — container không gọi trực tiếp vào host kernel. Giảm attack surface đáng kể.

### RuntimeClass trong Kubernetes

**RuntimeClass** là Kubernetes resource cho phép chỉ định runtime cho từng pod:

```yaml
# Tạo RuntimeClass
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc  # Tên handler trên node (phải khớp với containerd config)
```

```yaml
# Dùng trong pod
spec:
  runtimeClassName: gvisor  # Tham chiếu đến RuntimeClass
  containers: [...]
```

### Khi nào dùng sandbox runtime?

- Workload xử lý dữ liệu không tin cậy (user-uploaded content)
- Multi-tenant environment (nhiều khách hàng trên cùng cluster)
- Workload có yêu cầu compliance cao (PCI-DSS, HIPAA)
- Khi cần cô lập mạnh hơn giữa các tenant

> **Lưu ý:** Trong lab này, gVisor có thể chưa được cài đặt trên node. Bài lab tập trung vào việc tạo đúng cấu hình RuntimeClass và pod spec — pod có thể ở trạng thái `Pending` nếu node không hỗ trợ `runsc`.

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty cung cấp dịch vụ multi-tenant. Một số workload xử lý dữ liệu nhạy cảm từ nhiều khách hàng khác nhau và cần được cô lập mạnh hơn so với container thông thường.

Nhiệm vụ của bạn là:
1. Tạo `RuntimeClass` `gvisor` sử dụng handler `runsc` (gVisor runtime)
2. Tạo pod `sandboxed-pod` trong namespace `runtime-lab` với `runtimeClassName: gvisor`
3. Xác minh pod được cấu hình đúng

**Lưu ý:** Trong môi trường lab, gVisor có thể chưa được cài đặt trên node. Bài lab tập trung vào việc tạo đúng cấu hình RuntimeClass và pod spec — pod có thể ở trạng thái `Pending` nếu node không hỗ trợ `runsc`.

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- (Tùy chọn) gVisor đã được cài đặt trên node worker: [https://gvisor.dev/docs/user_guide/install/](https://gvisor.dev/docs/user_guide/install/)

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Tạo RuntimeClass gvisor

```bash
kubectl apply -f - <<EOF
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
EOF
```

**Giải thích:**
- `name: gvisor`: Tên RuntimeClass — được tham chiếu trong pod spec
- `handler: runsc`: Tên handler trên node — phải khớp với tên được cấu hình trong containerd/CRI-O

### Bước 2: Xác minh RuntimeClass đã được tạo

```bash
kubectl get runtimeclass
# NAME     HANDLER   AGE
# gvisor   runsc     10s

kubectl describe runtimeclass gvisor
```

### Bước 3: Tạo pod sandboxed-pod với runtimeClassName: gvisor

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-pod
  namespace: runtime-lab
  labels:
    app: sandboxed-pod
spec:
  runtimeClassName: gvisor
  containers:
  - name: app
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
EOF
```

### Bước 4: Xác minh pod được cấu hình đúng

```bash
# Kiểm tra pod
kubectl get pod sandboxed-pod -n runtime-lab

# Xác minh runtimeClassName trong pod spec
kubectl get pod sandboxed-pod -n runtime-lab \
  -o jsonpath='{.spec.runtimeClassName}'
# gvisor

# Xem chi tiết pod
kubectl describe pod sandboxed-pod -n runtime-lab
```

**Lưu ý:** Nếu gVisor chưa được cài đặt trên node, pod sẽ ở trạng thái `Pending` với lý do `RuntimeClass not found` hoặc `handler not found`. Đây là hành vi bình thường trong môi trường lab không có gVisor.

### Bước 5: (Nếu gVisor đã cài đặt) Xác minh sandbox isolation

```bash
# Trong container gVisor, kernel version sẽ khác với host
kubectl exec sandboxed-pod -n runtime-lab -- uname -r
# Kết quả: phiên bản kernel của gVisor (khác với host kernel)

# So sánh với pod thông thường
kubectl run normal-pod --image=nginx:1.25-alpine --restart=Never -n runtime-lab
kubectl exec normal-pod -n runtime-lab -- uname -r
# Kết quả: phiên bản kernel của host
```

### Bước 6: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] `RuntimeClass` `gvisor` tồn tại trong cluster với handler `runsc`
- [ ] Pod `sandboxed-pod` trong namespace `runtime-lab` có `runtimeClassName: gvisor`
- [ ] Namespace `runtime-lab` tồn tại

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cú pháp RuntimeClass</summary>

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor          # Tên dùng trong pod spec
handler: runsc          # Handler trên node (phải khớp với containerd config)
```

RuntimeClass là cluster-scoped resource (không thuộc namespace).

Để xem tất cả RuntimeClass:
```bash
kubectl get runtimeclass
```

</details>

<details>
<summary>Gợi ý 2: Cú pháp runtimeClassName trong pod</summary>

```yaml
spec:
  runtimeClassName: gvisor   # Phải khớp với tên RuntimeClass
  containers:
  - name: app
    image: nginx:1.25-alpine
```

`runtimeClassName` là field trong `spec` của Pod, không phải trong `metadata`.

</details>

<details>
<summary>Gợi ý 3: Cài đặt gVisor trên node (tùy chọn)</summary>

Nếu muốn pod thực sự chạy với gVisor:

```bash
# Trên node worker, cài đặt gVisor
curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" | sudo tee /etc/apt/sources.list.d/gvisor.list > /dev/null
sudo apt-get update && sudo apt-get install -y runsc

# Cấu hình containerd để dùng runsc
sudo tee /etc/containerd/config.toml <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF

sudo systemctl restart containerd
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### RuntimeClass là gì?

`RuntimeClass` là Kubernetes resource cho phép chỉ định container runtime khác nhau cho từng pod. Điều này cho phép:
- Chạy workload nhạy cảm với sandbox runtime (gVisor, kata-containers)
- Chạy workload thông thường với runtime mặc định (runc)
- Áp dụng chính sách runtime khác nhau cho từng loại workload

### gVisor là gì?

gVisor là sandbox runtime do Google phát triển, cung cấp lớp cô lập bổ sung:
- Intercept system calls từ container và xử lý trong user space
- Container không gọi trực tiếp vào host kernel
- Giảm attack surface đáng kể so với container thông thường

### So sánh các sandbox runtime

| Runtime | Handler | Cơ chế | Overhead |
|---------|---------|--------|---------|
| runc (mặc định) | runc | Namespace + cgroups | Thấp |
| gVisor | runsc | User-space kernel | Trung bình |
| kata-containers | kata | VM-based | Cao |

### Khi nào dùng sandbox runtime?

- Workload xử lý dữ liệu không tin cậy (user-uploaded content)
- Multi-tenant environment
- Workload có yêu cầu compliance cao (PCI-DSS, HIPAA)
- Khi cần cô lập mạnh hơn giữa các tenant

---

## Tham khảo

- [Kubernetes RuntimeClass Documentation](https://kubernetes.io/docs/concepts/containers/runtime-class/)
- [gVisor Documentation](https://gvisor.dev/docs/)
- [kata-containers](https://katacontainers.io/)
- [CKS Exam Curriculum – Minimize Microservice Vulnerabilities](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
