# Lab 1.4 – CIS Benchmark với kube-bench

**Domain:** Cluster Setup (15%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Chạy `kube-bench` để kiểm tra cấu hình CIS Kubernetes Benchmark trên kube-apiserver, etcd, và kubelet
- Xác định các mục FAIL trong kết quả kiểm tra
- Sửa ít nhất 2 vấn đề phổ biến: tắt profiling (`--profiling=false`) và tắt anonymous authentication (`--anonymous-auth=false`) trên kube-apiserver

---

## Lý thuyết

### CIS Benchmark là gì?

**CIS (Center for Internet Security)** là tổ chức phi lợi nhuận chuyên phát triển các tiêu chuẩn bảo mật được cộng đồng đồng thuận. **CIS Kubernetes Benchmark** là tập hợp các best practice bảo mật cho Kubernetes cluster, bao gồm hàng trăm kiểm tra cụ thể cho từng thành phần.

Mỗi kiểm tra có dạng:
- **ID**: Ví dụ `1.2.1` (Section 1, Subsection 2, Check 1)
- **Mô tả**: "Ensure that the --anonymous-auth argument is set to false"
- **Lý do**: Tại sao cần thiết
- **Cách sửa**: Lệnh hoặc cấu hình cụ thể

### kube-bench là gì?

**kube-bench** là công cụ open-source của Aqua Security tự động hóa việc kiểm tra CIS Kubernetes Benchmark. Thay vì kiểm tra thủ công từng item, kube-bench chạy tất cả checks và báo cáo kết quả:

```
[PASS] 1.2.1 Ensure that the --anonymous-auth argument is set to false
[FAIL] 1.2.16 Ensure that the --profiling argument is set to false
[WARN] 1.2.20 Ensure that the --audit-log-path argument is set
[INFO] 1.2.21 Ensure that the --audit-log-maxage argument is set to 30 or as appropriate
```

### Các thành phần được kiểm tra

| Section | Thành phần | Ví dụ checks |
|---------|-----------|--------------|
| 1.x | kube-apiserver | anonymous-auth, audit logging, TLS |
| 2.x | etcd | TLS, authentication |
| 3.x | Control Plane | Scheduler, Controller Manager |
| 4.x | Worker Node | kubelet config, file permissions |
| 5.x | Policies | RBAC, Network Policies |

### Các flag quan trọng của kube-apiserver

Hai flag thường bị FAIL nhất trong CKS:

**`--anonymous-auth=false`**
- Mặc định: `true` — cho phép request không có credentials với identity `system:anonymous`
- Rủi ro: Nếu RBAC cấu hình sai, anonymous user có thể truy cập API
- Fix: Thêm `--anonymous-auth=false` vào kube-apiserver manifest

**`--profiling=false`**
- Mặc định: `true` — expose endpoint `/debug/pprof` chứa thông tin profiling
- Rủi ro: Lộ thông tin về cấu trúc nội bộ, có thể bị dùng để tấn công DoS
- Fix: Thêm `--profiling=false` vào kube-apiserver manifest

### kube-apiserver là static pod

Trên cluster được tạo bởi kubeadm, kube-apiserver chạy dưới dạng **static pod** — được quản lý bởi kubelet thông qua file manifest tại:

```
/etc/kubernetes/manifests/kube-apiserver.yaml
```

Khi bạn sửa file này, kubelet **tự động** phát hiện thay đổi và restart kube-apiserver (khoảng 30-60 giây). Không cần chạy lệnh restart thủ công.

```bash
# Backup trước khi sửa
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak

# Sửa manifest
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

# Theo dõi quá trình restart
kubectl get pods -n kube-system -l component=kube-apiserver -w
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật vừa tiếp nhận một Kubernetes cluster mới. Trước khi đưa vào production, bạn cần kiểm tra cluster có tuân thủ CIS Kubernetes Benchmark không. Công cụ `kube-bench` của Aqua Security tự động hóa quá trình này bằng cách kiểm tra các cấu hình theo tiêu chuẩn CIS.

Nhiệm vụ của bạn:
1. Chạy `kube-bench` và xem kết quả cho các thành phần chính
2. Xác định các mục FAIL liên quan đến kube-apiserver
3. Sửa cấu hình `--profiling=false` và `--anonymous-auth=false` trên kube-apiserver
4. Chạy lại `kube-bench` để xác nhận các mục đã được sửa

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29 (kubeadm-based cluster được khuyến nghị)
- `kubectl` đã được cấu hình và kết nối đến cluster
- `kube-bench` đã được cài đặt trên control-plane node
- Quyền truy cập SSH vào control-plane node (để chỉnh sửa kube-apiserver manifest)

Cài đặt kube-bench (nếu chưa có):
```bash
# Tải binary mới nhất
curl -L https://github.com/aquasecurity/kube-bench/releases/latest/download/kube-bench_linux_amd64.tar.gz | tar xz
sudo mv kube-bench /usr/local/bin/
```

Chạy script khởi tạo môi trường:
```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Chạy kube-bench cho toàn bộ cluster

```bash
# Chạy tất cả các kiểm tra (cần chạy trên control-plane node)
sudo kube-bench run --targets master,etcd,node

# Hoặc chạy riêng từng thành phần
sudo kube-bench run --targets master
sudo kube-bench run --targets etcd
sudo kube-bench run --targets node
```

### Bước 2: Lọc các mục FAIL

```bash
# Chỉ xem các mục FAIL
sudo kube-bench run --targets master 2>/dev/null | grep -E "^\[FAIL\]"

# Lưu kết quả vào file để phân tích
sudo kube-bench run --targets master > /tmp/kube-bench-master.txt 2>&1
grep -E "^\[FAIL\]" /tmp/kube-bench-master.txt
```

### Bước 3: Xác định vấn đề với kube-apiserver

Tìm các mục FAIL liên quan đến profiling và anonymous-auth:

```bash
grep -E "profiling|anonymous" /tmp/kube-bench-master.txt
```

Kết quả mong đợi sẽ bao gồm:
- `[FAIL] 1.2.16 Ensure that the --profiling argument is set to false`
- `[FAIL] 1.2.1 Ensure that the --anonymous-auth argument is set to false`

### Bước 4: Sửa cấu hình kube-apiserver

Kube-apiserver trên kubeadm cluster được quản lý qua static pod manifest:

```bash
# Backup manifest trước khi sửa
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak

# Chỉnh sửa manifest
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Tìm phần `command:` và thêm các flag sau:

```yaml
- --profiling=false
- --anonymous-auth=false
```

### Bước 5: Xác nhận kube-apiserver đã khởi động lại

Sau khi lưu file manifest, kubelet sẽ tự động khởi động lại kube-apiserver:

```bash
# Chờ kube-apiserver khởi động lại (khoảng 30-60 giây)
kubectl wait --for=condition=Ready pod/kube-apiserver-$(hostname) -n kube-system --timeout=120s

# Kiểm tra các flag đã được áp dụng
kubectl get pod kube-apiserver-$(hostname) -n kube-system -o yaml | grep -E "profiling|anonymous-auth"
```

### Bước 6: Chạy lại kube-bench để xác nhận

```bash
sudo kube-bench run --targets master 2>/dev/null | grep -E "profiling|anonymous"
```

### Bước 7: Kiểm tra kết quả

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] `kube-bench` đã được cài đặt và có thể chạy được
- [ ] kube-apiserver có flag `--profiling=false`
- [ ] kube-apiserver có flag `--anonymous-auth=false`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Tìm file manifest kube-apiserver ở đâu?</summary>

Trên cluster được tạo bởi kubeadm, các static pod manifest nằm tại:
```
/etc/kubernetes/manifests/kube-apiserver.yaml
```

Kubelet theo dõi thư mục này và tự động khởi động lại pod khi file thay đổi. Không cần chạy lệnh restart thủ công.

</details>

<details>
<summary>Gợi ý 2: Cách kiểm tra flag hiện tại của kube-apiserver</summary>

```bash
# Xem tất cả flag đang chạy
kubectl get pod kube-apiserver-$(hostname) -n kube-system -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n'

# Hoặc xem process trực tiếp
ps aux | grep kube-apiserver | grep -v grep
```

</details>

<details>
<summary>Gợi ý 3: kube-bench báo FAIL nhưng flag đã có — tại sao?</summary>

Một số lý do phổ biến:
- Flag được đặt thành `true` thay vì `false` (ví dụ: `--profiling=true`)
- Có khoảng trắng thừa trong giá trị flag
- kube-apiserver chưa khởi động lại sau khi sửa manifest

Kiểm tra lại:
```bash
kubectl get pod kube-apiserver-$(hostname) -n kube-system -o yaml | grep -A1 "profiling"
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có hướng dẫn chi tiết và các lệnh kube-bench.

</details>

---

## Giải thích

### Tại sao cần tắt Profiling?

`--profiling=true` (mặc định) cho phép truy cập endpoint `/debug/pprof` trên kube-apiserver. Endpoint này có thể tiết lộ thông tin nhạy cảm về hiệu suất và cấu trúc nội bộ của API server, có thể bị khai thác để:
- Thu thập thông tin về cluster topology
- Tấn công DoS thông qua profiling requests tốn tài nguyên

### Tại sao cần tắt Anonymous Authentication?

`--anonymous-auth=true` (mặc định) cho phép các request không có credentials truy cập API server với user `system:anonymous`. Mặc dù RBAC có thể giới hạn quyền của anonymous user, việc tắt hoàn toàn là best practice vì:
- Giảm attack surface
- Ngăn chặn các lỗi cấu hình RBAC vô tình cấp quyền cho anonymous
- Tuân thủ CIS Benchmark requirement 1.2.1

### CIS Benchmark là gì?

CIS (Center for Internet Security) Kubernetes Benchmark là tập hợp các best practice bảo mật được cộng đồng đồng thuận. `kube-bench` tự động kiểm tra cluster của bạn theo các tiêu chuẩn này và phân loại kết quả thành PASS, FAIL, WARN, INFO.

---

## Tham khảo

- [kube-bench GitHub](https://github.com/aquasecurity/kube-bench)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [kube-apiserver Security Flags](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
- [CKS Exam Curriculum – Cluster Setup](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
