# Lab 6.4 – Behavioral Analytics với Falco

**Domain:** Monitoring, Logging and Runtime Security (20%)
**Thời gian ước tính:** 25 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Viết Falco rule nâng cao phát hiện khi tiến trình đọc file nhạy cảm (`/etc/shadow`, `/etc/passwd`) trong container
- Viết Falco rule phát hiện outbound network connection bất thường từ container
- Cấu hình Falco output ghi alert ra file `/tmp/falco-alerts.log`
- Trigger các hành vi độc hại có kiểm soát và xác minh alert xuất hiện trong log

---

## Bối cảnh

Bạn là security engineer đang thiết lập behavioral analytics nâng cao cho cluster production. Sau khi đã cấu hình phát hiện shell spawn cơ bản (Lab 6.1), bạn cần nâng cấp lên phát hiện các pattern tấn công phức tạp hơn: đọc file credential nhạy cảm và egress connections bất thường.

**Sự khác biệt với Lab 6.1:**
- **Lab 6.1** phát hiện shell spawn (`spawned_process and shell_procs`) — dấu hiệu kẻ tấn công đang tương tác với container
- **Lab 6.4** phát hiện syscall/process behavior nâng cao:
  - Đọc file nhạy cảm (`fd.name in (/etc/shadow, /etc/passwd)`) — dấu hiệu credential harvesting
  - Outbound network connections (`evt.type = connect and container`) — dấu hiệu data exfiltration hoặc C2 communication
  - Privilege escalation (`evt.type = setuid`) — dấu hiệu leo thang đặc quyền

Nhiệm vụ của bạn là:
1. Viết Falco rule phát hiện đọc `/etc/shadow` và `/etc/passwd` trong container
2. Viết Falco rule phát hiện outbound network connection từ container
3. Cấu hình Falco output ghi alert ra `/tmp/falco-alerts.log`
4. Trigger các hành vi và xác minh alert xuất hiện trong log

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- `falco` đã được cài đặt (systemd service hoặc DaemonSet):
  - [https://falco.org/docs/getting-started/installation/](https://falco.org/docs/getting-started/installation/)
- Quyền truy cập node để chỉnh sửa Falco config và rules

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Viết Falco rule phát hiện đọc file nhạy cảm

Tạo file rule tại `/etc/falco/rules.d/behavioral-rules.yaml`:

```bash
sudo nano /etc/falco/rules.d/behavioral-rules.yaml
```

Thêm rule phát hiện đọc `/etc/shadow` và `/etc/passwd`:

```yaml
- rule: Sensitive File Read in Container
  desc: Phát hiện khi tiến trình đọc file credential nhạy cảm trong container
  condition: >
    open_read and container
    and fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers)
  output: >
    Sensitive file read in container
    (user=%user.name user_uid=%user.uid
    file=%fd.name proc=%proc.name cmdline=%proc.cmdline
    container_id=%container.id image=%container.image.repository
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, credential_access, mitre_credential_access, cks_lab]
```

### Bước 2: Viết Falco rule phát hiện outbound network connection

Thêm rule phát hiện egress connection vào cùng file:

```yaml
- rule: Unexpected Outbound Connection from Container
  desc: Phát hiện khi container thực hiện outbound network connection
  condition: >
    evt.type = connect and container
    and not fd.sip in (127.0.0.1, ::1)
    and fd.typechar = 4
  output: >
    Unexpected outbound connection from container
    (user=%user.name proc=%proc.name cmdline=%proc.cmdline
    connection=%fd.name container_id=%container.id
    image=%container.image.repository
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: WARNING
  tags: [container, network, mitre_exfiltration, cks_lab]
```

### Bước 3: Cấu hình Falco output ghi ra file

Chỉnh sửa `/etc/falco/falco.yaml` để thêm file output:

```bash
sudo nano /etc/falco/falco.yaml
```

Tìm section `file_output` và cấu hình:

```yaml
file_output:
  enabled: true
  keep_alive: false
  filename: /tmp/falco-alerts.log
```

### Bước 4: Load rule và restart Falco

```bash
# Validate rule file trước khi apply
sudo falco --validate /etc/falco/rules.d/behavioral-rules.yaml

# Restart Falco để load rule mới và cấu hình output
sudo systemctl restart falco

# Xác minh Falco đang chạy
sudo systemctl status falco
```

Nếu Falco chạy dưới dạng DaemonSet:

```bash
# Tạo ConfigMap từ rule file
kubectl create configmap falco-behavioral-rules \
  --from-file=behavioral-rules.yaml=/etc/falco/rules.d/behavioral-rules.yaml \
  -n falco --dry-run=client -o yaml | kubectl apply -f -

# Restart DaemonSet
kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco
```

### Bước 5: Trigger các hành vi độc hại

Sử dụng script trigger đã được tạo bởi `setup.sh`:

```bash
bash /tmp/trigger-behaviors.sh
```

Hoặc trigger thủ công:

```bash
# Trigger đọc file nhạy cảm
kubectl exec attacker-sim -n falco-behavioral-lab -- cat /etc/passwd
kubectl exec attacker-sim -n falco-behavioral-lab -- cat /etc/shadow 2>/dev/null || true

# Trigger network connection
kubectl exec attacker-sim -n falco-behavioral-lab -- wget -q --timeout=3 http://1.1.1.1 -O /dev/null 2>/dev/null || true
```

### Bước 6: Xác minh alert trong log

```bash
# Kiểm tra file log
cat /tmp/falco-alerts.log

# Tìm alert cụ thể
grep -i "shadow\|passwd" /tmp/falco-alerts.log
grep -i "outbound\|connect" /tmp/falco-alerts.log

# Xem realtime
sudo tail -f /tmp/falco-alerts.log
```

### Bước 7: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Falco service đang chạy (systemd service hoặc DaemonSet)
- [ ] File rule tùy chỉnh tồn tại tại `/etc/falco/rules.d/` (bất kỳ file `.yaml` nào)
- [ ] File `/tmp/falco-alerts.log` tồn tại và chứa ít nhất 1 alert

---

## Gợi ý

<details>
<summary>Gợi ý 1: Falco filter fields cho file access</summary>

Các field hữu ích để phát hiện file access:

```yaml
# Macro open_read: evt.type in (open, openat, openat2) and evt.is_open_read = true
# Dùng macro này thay vì evt.type = open để bắt tất cả syscall mở file

# Field fd.name: đường dẫn đầy đủ của file
fd.name in (/etc/shadow, /etc/passwd)

# Kết hợp với container filter
container.id != host   # hoặc dùng macro: container

# Ví dụ condition đầy đủ:
condition: open_read and container and fd.name in (/etc/shadow, /etc/passwd)
```

</details>

<details>
<summary>Gợi ý 2: Falco filter fields cho network connection</summary>

```yaml
# evt.type = connect: syscall connect() - khi process tạo outbound connection
# fd.typechar = 4: IPv4 socket (6 = IPv6)
# fd.sip: server IP (destination IP)

# Loại trừ localhost để tránh false positive
condition: >
  evt.type = connect and container
  and not fd.sip in (127.0.0.1, ::1)
  and fd.typechar = 4

# Field hữu ích trong output:
# fd.name: "IP:port->IP:port" format
# fd.sip: destination IP
# fd.sport: destination port
```

</details>

<details>
<summary>Gợi ý 3: Cấu hình Falco file output</summary>

Trong `/etc/falco/falco.yaml`, tìm và sửa section `file_output`:

```yaml
# Bật file output
file_output:
  enabled: true
  keep_alive: false
  filename: /tmp/falco-alerts.log

# Đảm bảo json_output: false để output dạng text (dễ đọc hơn)
# Hoặc json_output: true nếu muốn parse bằng script
json_output: false
```

Sau khi sửa, restart Falco:
```bash
sudo systemctl restart falco
```

</details>

<details>
<summary>Gợi ý 4: Kiểm tra Falco đang chạy</summary>

```bash
# Kiểm tra systemd service
systemctl status falco
systemctl is-active falco

# Kiểm tra DaemonSet
kubectl get daemonset -n falco
kubectl get pods -n falco -l app=falco

# Xem logs Falco
sudo journalctl -u falco -f
kubectl logs -n falco -l app=falco --tail=50
```

</details>

<details>
<summary>Gợi ý 5: Cài đặt Falco bằng Helm</summary>

```bash
# Thêm Helm repo
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Cài đặt Falco với eBPF driver
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set driver.kind=ebpf \
  --set falco.json_output=false \
  --set falco.file_output.enabled=true \
  --set falco.file_output.filename=/tmp/falco-alerts.log

# Chờ DaemonSet sẵn sàng
kubectl rollout status daemonset/falco -n falco
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

### Behavioral Analytics vs Shell Spawn Detection

| Khía cạnh | Lab 6.1 – Shell Spawn | Lab 6.4 – Behavioral Analytics |
|-----------|----------------------|-------------------------------|
| Phát hiện | Shell process được tạo | Syscall/file access/network behavior |
| Kỹ thuật | `spawned_process and shell_procs` | `open_read`, `evt.type = connect`, `evt.type = setuid` |
| Mức độ | Cơ bản | Nâng cao |
| False positive | Thấp (shell spawn rõ ràng) | Cần tuning (nhiều process đọc /etc/passwd) |
| Ứng dụng | Phát hiện interactive access | Phát hiện credential harvesting, C2, privilege escalation |

### Tại sao behavioral analytics quan trọng?

Kẻ tấn công ngày càng tinh vi hơn — họ có thể:
- **Không spawn shell**: Dùng reverse shell trong process hiện có
- **Đọc credential**: `cat /etc/shadow` để crack password offline
- **Exfiltrate data**: Kết nối đến C2 server để gửi dữ liệu
- **Escalate privilege**: Dùng `setuid` binary để leo thang đặc quyền

Behavioral analytics phát hiện các hành vi này ở tầng syscall — không thể bypass bằng cách đổi tên process hay dùng shell khác.

### Falco syscall monitoring

Falco sử dụng kernel-level monitoring:
1. **eBPF probe** (khuyến nghị): Intercept syscall an toàn, không cần kernel module
2. **Kernel module**: Hiệu năng cao hơn nhưng cần compile cho từng kernel version
3. **Rules engine**: So sánh syscall với rules đã định nghĩa theo thời gian thực

### Best practices cho behavioral rules

- **Tuning**: Bắt đầu với `priority: WARNING` rồi điều chỉnh sau khi xem false positive
- **Whitelist**: Dùng `not proc.name in (...)` để loại trừ process hợp lệ
- **Tagging**: Dùng MITRE ATT&CK tags để phân loại alert (`mitre_credential_access`, `mitre_exfiltration`)
- **Output format**: Bao gồm đủ context (container ID, pod name, namespace) để điều tra

---

## Tham khảo

- [Falco Documentation](https://falco.org/docs/)
- [Falco Rules Reference](https://falco.org/docs/rules/)
- [Falco Supported Fields](https://falco.org/docs/reference/rules/supported-fields/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- [CKS Exam – Monitoring, Logging and Runtime Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
