# Giải pháp mẫu – Lab 1.4: CIS Benchmark với kube-bench

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## Bước 1: Cài đặt kube-bench

```bash
# Tải và cài đặt binary
curl -L https://github.com/aquasecurity/kube-bench/releases/latest/download/kube-bench_linux_amd64.tar.gz | tar xz
sudo mv kube-bench /usr/local/bin/
sudo chmod +x /usr/local/bin/kube-bench

# Xác nhận cài đặt
kube-bench version
```

---

## Bước 2: Chạy kube-bench

```bash
# Kiểm tra toàn bộ control-plane
sudo kube-bench run --targets master 2>/dev/null

# Lưu kết quả để phân tích
sudo kube-bench run --targets master > /tmp/kube-bench-master.txt 2>&1

# Xem chỉ các mục FAIL
grep "^\[FAIL\]" /tmp/kube-bench-master.txt

# Xem tóm tắt
grep -A5 "== Summary ==" /tmp/kube-bench-master.txt
```

Kết quả mẫu (một số mục FAIL phổ biến):
```
[FAIL] 1.2.1  Ensure that the --anonymous-auth argument is set to false
[FAIL] 1.2.16 Ensure that the --profiling argument is set to false
[FAIL] 1.2.18 Ensure that the --audit-log-path argument is set
[FAIL] 1.2.19 Ensure that the --audit-log-maxage argument is set to 30 or as appropriate
```

---

## Bước 3: Backup và sửa kube-apiserver manifest

```bash
# Backup manifest hiện tại
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak

# Xem cấu hình hiện tại
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A50 "command:"
```

Sửa manifest để thêm các flag bảo mật:

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Tìm phần `command:` và thêm các dòng sau (thứ tự không quan trọng):

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --advertise-address=<IP>
    - --allow-privileged=true
    - --anonymous-auth=false          # THÊM DÒNG NÀY
    - --authorization-mode=Node,RBAC
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    # ... các flag khác ...
    - --profiling=false               # THÊM DÒNG NÀY
    # ... tiếp tục ...
```

---

## Bước 4: Xác nhận kube-apiserver đã khởi động lại

```bash
# Kubelet tự động phát hiện thay đổi và restart kube-apiserver
# Chờ khoảng 30-60 giây

# Kiểm tra pod đang chạy
kubectl get pods -n kube-system | grep kube-apiserver

# Xác nhận các flag đã được áp dụng
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | grep -E "profiling|anonymous"
```

Kết quả mong đợi:
```
--anonymous-auth=false
--profiling=false
```

---

## Bước 5: Chạy lại kube-bench để xác nhận

```bash
sudo kube-bench run --targets master 2>/dev/null | grep -E "1\.2\.1|1\.2\.16"
```

Kết quả mong đợi:
```
[PASS] 1.2.1  Ensure that the --anonymous-auth argument is set to false
[PASS] 1.2.16 Ensure that the --profiling argument is set to false
```

---

## Các mục FAIL phổ biến khác và cách sửa

### 1.2.18 – Audit log path

```yaml
# Thêm vào kube-apiserver command:
- --audit-log-path=/var/log/kubernetes/audit.log
- --audit-log-maxage=30
- --audit-log-maxbackup=10
- --audit-log-maxsize=100
- --audit-policy-file=/etc/kubernetes/audit-policy.yaml
```

### 1.2.6 – AlwaysAdmit admission plugin

```yaml
# Đảm bảo AlwaysAdmit KHÔNG có trong danh sách:
- --enable-admission-plugins=NodeRestriction,PodSecurity
# KHÔNG dùng: --enable-admission-plugins=AlwaysAdmit,...
```

### etcd – Peer TLS

```bash
# Kiểm tra etcd
sudo kube-bench run --targets etcd 2>/dev/null | grep "^\[FAIL\]"
```

---

## Tham khảo

- [kube-bench GitHub](https://github.com/aquasecurity/kube-bench)
- [CIS Kubernetes Benchmark v1.9](https://www.cisecurity.org/benchmark/kubernetes)
- [kube-apiserver Reference](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
