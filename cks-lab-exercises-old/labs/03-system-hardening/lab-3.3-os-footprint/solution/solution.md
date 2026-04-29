# Giải pháp mẫu – Lab 3.3: Minimize OS Footprint

---

## Bước 1: Liệt kê package không cần thiết

### Debian/Ubuntu (dpkg)

```bash
# Liệt kê tất cả package đã cài
dpkg --list

# Lọc các package không cần thiết và ghi vào file
dpkg --list | grep -E "telnet|nmap|netcat" | tee /tmp/unnecessary-packages.txt

# Xác minh file đã được tạo
cat /tmp/unnecessary-packages.txt
```

### RHEL/CentOS (rpm)

```bash
# Liệt kê tất cả package đã cài
rpm -qa

# Lọc các package không cần thiết và ghi vào file
rpm -qa | grep -E "telnet|nmap|netcat" | tee /tmp/unnecessary-packages.txt
```

---

## Bước 2: Disable service không cần thiết

```bash
# Disable dummy service được tạo bởi setup.sh
sudo systemctl disable --now lab-dummy.service

# Xác minh service đã disabled
systemctl is-enabled lab-dummy.service
# Kết quả: disabled

systemctl is-active lab-dummy.service
# Kết quả: inactive
```

### Các service thường cần disable trên Kubernetes node

```bash
# Disable snapd (package manager không cần thiết trên server)
sudo systemctl disable --now snapd

# Disable bluetooth (không cần thiết trên server/VM)
sudo systemctl disable --now bluetooth

# Disable avahi-daemon (mDNS service, không cần thiết)
sudo systemctl disable --now avahi-daemon

# Disable cups (print service, không cần thiết)
sudo systemctl disable --now cups

# Disable rpcbind (RPC portmapper, không cần nếu không dùng NFS)
sudo systemctl disable --now rpcbind
```

---

## Bước 3: Kiểm tra port đang lắng nghe

```bash
# Kiểm tra port TCP đang lắng nghe và ghi vào file
ss -tlnp > /tmp/open-ports.txt

# Xem kết quả
cat /tmp/open-ports.txt
```

Kết quả mẫu:

```
State    Recv-Q   Send-Q   Local Address:Port   Peer Address:Port   Process
LISTEN   0        128      0.0.0.0:22           0.0.0.0:*           users:(("sshd",pid=1234,fd=3))
LISTEN   0        128      0.0.0.0:10250        0.0.0.0:*           users:(("kubelet",pid=5678,fd=9))
```

---

## Giải thích CIS Benchmark Section 4

CIS Benchmark Section 4 (Worker Node Security Configuration) định nghĩa các tiêu chuẩn bảo mật cho Kubernetes worker node. Các nguyên tắc chính liên quan đến OS footprint:

### 4.1 Worker Node Configuration Files

| CIS Check | Mô tả | Lệnh kiểm tra |
|-----------|-------|---------------|
| 4.1.1 | kubelet service file permissions ≤ 644 | `stat /etc/systemd/system/kubelet.service` |
| 4.1.5 | kubelet.conf permissions ≤ 644 | `stat /etc/kubernetes/kubelet.conf` |
| 4.1.9 | kubelet config.yaml permissions ≤ 644 | `stat /var/lib/kubelet/config.yaml` |

### 4.2 Kubelet

| CIS Check | Mô tả | Cấu hình |
|-----------|-------|----------|
| 4.2.1 | `--anonymous-auth=false` | Ngăn truy cập ẩn danh vào kubelet API |
| 4.2.2 | `--authorization-mode≠AlwaysAllow` | Yêu cầu authorization |
| 4.2.6 | `--protect-kernel-defaults=true` | Bảo vệ kernel parameters |

### Tại sao Minimize OS Footprint quan trọng?

1. **Giảm attack surface**: Mỗi package/service là một điểm có thể bị exploit
2. **Ngăn lateral movement**: Kẻ tấn công không thể dùng `nmap`, `netcat` để scan mạng nội bộ
3. **Giảm CVE exposure**: Ít package hơn = ít lỗ hổng bảo mật tiềm ẩn hơn
4. **Compliance**: Đáp ứng yêu cầu CIS Benchmark và các tiêu chuẩn bảo mật

### Danh sách service thường cần disable

| Service | Lý do |
|---------|-------|
| `snapd` | Package manager không cần thiết trên production server |
| `bluetooth` | Không có phần cứng Bluetooth trên server/VM |
| `avahi-daemon` | mDNS/DNS-SD, không cần thiết trong môi trường có DNS |
| `cups` | Print service, không cần thiết trên server |
| `rpcbind` | RPC portmapper, chỉ cần nếu dùng NFS |
| `postfix` | Mail server, không cần thiết nếu không gửi mail |
| `nfs-server` | NFS server, chỉ cần nếu chia sẻ file qua NFS |

---

## Xác minh kết quả

```bash
# Chạy verify script
bash verify.sh

# Kết quả mong đợi:
# [PASS] File /tmp/unnecessary-packages.txt tồn tại và có N dòng
# [PASS] lab-dummy.service đã được disable (systemctl is-enabled → disabled)
# [PASS] File /tmp/open-ports.txt tồn tại
# ==========================================
#  Kết quả: 3/3 tiêu chí đạt
# ==========================================
```
