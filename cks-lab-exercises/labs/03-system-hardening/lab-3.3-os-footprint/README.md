# Lab 3.3 – Minimize OS Footprint

**Domain:** System Hardening (10%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Xác định các package không cần thiết trên node bằng `dpkg --list` / `rpm -qa` và ghi danh sách vào `/tmp/unnecessary-packages.txt`
- Tắt và disable ít nhất 1 service không cần thiết bằng `systemctl disable --now`
- Kiểm tra các port đang lắng nghe bằng `ss -tlnp` và ghi kết quả vào `/tmp/open-ports.txt`

---

## Bối cảnh

Bạn là kỹ sư bảo mật vừa tiếp nhận một worker node mới và cần hardening trước khi đưa vào production cluster. Theo CIS Benchmark Section 4 (Worker Node Security Configuration), mọi package và service không cần thiết phải được loại bỏ để giảm thiểu attack surface.

Nhiệm vụ của bạn là:
1. Liệt kê các package đã cài đặt và xác định package không cần thiết
2. Tắt và disable các service không dùng đến
3. Kiểm tra các port đang mở để đảm bảo chỉ có các port cần thiết

---

## Yêu cầu môi trường

- Linux node (Debian/Ubuntu hoặc RHEL/CentOS)
- Quyền `sudo` hoặc root để disable service và cài/xóa package
- Không yêu cầu Kubernetes cluster (chạy trực tiếp trên node)

Chạy script khởi tạo môi trường:

```bash
sudo bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Liệt kê package đã cài đặt

Trên Debian/Ubuntu:

```bash
dpkg --list | grep -E "telnet|nmap|netcat" | tee /tmp/unnecessary-packages.txt
```

Trên RHEL/CentOS:

```bash
rpm -qa | grep -E "telnet|nmap|netcat" | tee /tmp/unnecessary-packages.txt
```

Xác minh file đã được tạo:

```bash
cat /tmp/unnecessary-packages.txt
```

### Bước 2: Tắt và disable service không cần thiết

Script `setup.sh` đã tạo sẵn một dummy service `lab-dummy.service` để bạn thực hành. Disable service này:

```bash
sudo systemctl disable --now lab-dummy.service
```

Nếu môi trường có các service thực tế không cần thiết, bạn cũng có thể disable chúng:

```bash
# Kiểm tra service đang chạy
systemctl list-units --type=service --state=running

# Disable service không cần thiết (ví dụ)
sudo systemctl disable --now snapd
sudo systemctl disable --now bluetooth
sudo systemctl disable --now avahi-daemon
```

Xác minh service đã được disable:

```bash
systemctl is-enabled lab-dummy.service
# Kết quả mong đợi: disabled
```

### Bước 3: Kiểm tra port đang lắng nghe

```bash
ss -tlnp | tee /tmp/open-ports.txt
```

Xem kết quả:

```bash
cat /tmp/open-ports.txt
```

### Bước 4: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] File `/tmp/unnecessary-packages.txt` tồn tại và không rỗng
- [ ] Ít nhất 1 service đã được disable (`lab-dummy.service` hoặc `snapd`/`bluetooth`/`avahi-daemon`)
- [ ] File `/tmp/open-ports.txt` tồn tại

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cách lọc package không cần thiết</summary>

Dùng `grep` để lọc các package cụ thể:

```bash
# Debian/Ubuntu — liệt kê tất cả package đã cài
dpkg --list

# Lọc các package thường không cần thiết trên server
dpkg --list | grep -E "telnet|nmap|netcat|wireshark|tcpdump"

# Ghi vào file
dpkg --list | grep -E "telnet|nmap|netcat" > /tmp/unnecessary-packages.txt
```

Nếu không có package nào khớp, bạn có thể ghi toàn bộ danh sách:

```bash
dpkg --list > /tmp/unnecessary-packages.txt
```

</details>

<details>
<summary>Gợi ý 2: Cách disable service với systemctl</summary>

```bash
# Disable và dừng service ngay lập tức
sudo systemctl disable --now lab-dummy.service

# Kiểm tra trạng thái
systemctl is-enabled lab-dummy.service   # → disabled
systemctl is-active lab-dummy.service    # → inactive

# Xem danh sách service đang chạy
systemctl list-units --type=service --state=running
```

Sự khác biệt giữa `stop` và `disable`:
- `systemctl stop`: dừng service ngay, nhưng sẽ tự khởi động lại khi reboot
- `systemctl disable`: ngăn service tự khởi động khi reboot
- `systemctl disable --now`: vừa disable vừa stop ngay lập tức

</details>

<details>
<summary>Gợi ý 3: Cách kiểm tra port đang mở</summary>

```bash
# ss — công cụ hiện đại thay thế netstat
ss -tlnp

# Giải thích các flag:
# -t: chỉ hiển thị TCP
# -l: chỉ hiển thị listening sockets
# -n: hiển thị số port thay vì tên service
# -p: hiển thị process đang dùng port

# Ghi kết quả vào file
ss -tlnp > /tmp/open-ports.txt
```

</details>

<details>
<summary>Cảnh báo: KHÔNG xóa package hệ thống quan trọng</summary>

**⚠️ QUAN TRỌNG:** Trong môi trường Kubernetes, KHÔNG xóa các package sau:

- `kubelet` — agent chạy trên mỗi node, cần thiết để node hoạt động
- `containerd` hoặc `docker` — container runtime, cần thiết để chạy pod
- `kubeadm` — công cụ quản lý cluster
- `kubectl` — CLI để tương tác với cluster

Xóa các package này sẽ làm hỏng node và có thể gây mất dữ liệu. Chỉ xóa các package thực sự không cần thiết như `telnet`, `nmap`, `netcat` sau khi đã xác nhận chúng không được dùng bởi bất kỳ service nào.

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### OS Footprint và CIS Benchmark Section 4

CIS Benchmark Section 4 (Worker Node Security Configuration) quy định rằng mỗi Kubernetes worker node phải được hardening để giảm thiểu attack surface. Nguyên tắc cốt lõi là **least privilege** — chỉ cài đặt và chạy những gì thực sự cần thiết.

**Tại sao OS footprint quan trọng?**

- **Package không cần thiết** như `telnet`, `nmap`, `netcat` có thể bị kẻ tấn công lợi dụng sau khi xâm nhập vào node để thực hiện lateral movement hoặc exfiltration
- **Service không cần thiết** tạo thêm attack surface — mỗi service chạy là một tiến trình có thể bị exploit
- **Port mở không cần thiết** là cửa vào tiềm năng cho kẻ tấn công

**CIS Benchmark Section 4 – Các kiểm tra liên quan:**

| CIS Check | Mô tả |
|-----------|-------|
| 4.1.1 | Đảm bảo kubelet service file permissions là 644 hoặc chặt hơn |
| 4.2.1 | Đảm bảo `--anonymous-auth` được set thành `false` |
| 4.2.6 | Đảm bảo `--protect-kernel-defaults` được set thành `true` |

**Nguyên tắc Minimize OS Footprint:**

1. **Xóa package không dùng**: Giảm số lượng binary có thể bị lạm dụng
2. **Disable service không dùng**: Giảm số tiến trình chạy và attack surface
3. **Đóng port không cần thiết**: Giảm số điểm vào mạng
4. **Dùng minimal base image**: Áp dụng nguyên tắc tương tự cho container image

### Service thường cần disable trên Kubernetes node

| Service | Lý do disable |
|---------|---------------|
| `snapd` | Package manager không cần thiết trên server |
| `bluetooth` | Không cần thiết trên server/VM |
| `avahi-daemon` | mDNS/DNS-SD service, không cần thiết |
| `cups` | Print service, không cần thiết |
| `rpcbind` | RPC portmapper, không cần thiết nếu không dùng NFS |

---

## Tham khảo

- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [CKS Exam Curriculum – System Hardening](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- [systemctl man page](https://man7.org/linux/man-pages/man1/systemctl.1.html)
- [ss man page](https://man7.org/linux/man-pages/man8/ss.8.html)
- [Kubernetes Node Security](https://kubernetes.io/docs/concepts/security/overview/)
