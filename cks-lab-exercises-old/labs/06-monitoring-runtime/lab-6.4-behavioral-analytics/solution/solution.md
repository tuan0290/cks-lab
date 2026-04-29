# Giải pháp – Lab 6.4 Behavioral Analytics với Falco

## Bước 1: Tạo Falco rule file

Tạo file `/etc/falco/rules.d/behavioral-rules.yaml` với 3 rule mẫu:

```bash
sudo tee /etc/falco/rules.d/behavioral-rules.yaml <<'EOF'
# Lab 6.4 – Behavioral Analytics Rules

# Rule 1: Phát hiện đọc file credential nhạy cảm trong container
- rule: Sensitive File Read in Container
  desc: Phát hiện khi tiến trình đọc file credential nhạy cảm (/etc/shadow, /etc/passwd) trong container
  condition: >
    open_read and container
    and fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers, /etc/sudoers.d)
  output: >
    Sensitive file read in container
    (user=%user.name user_uid=%user.uid
    file=%fd.name proc=%proc.name cmdline=%proc.cmdline
    container_id=%container.id image=%container.image.repository
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, credential_access, mitre_credential_access, cks_lab]

# Rule 2: Phát hiện outbound network connection từ container
- rule: Unexpected Outbound Connection from Container
  desc: Phát hiện khi container thực hiện outbound network connection đến IP ngoài cluster
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

# Rule 3: Phát hiện privilege escalation qua setuid
- rule: Setuid or Setgid in Container
  desc: Phát hiện khi tiến trình gọi setuid/setgid trong container (dấu hiệu privilege escalation)
  condition: >
    evt.type in (setuid, setgid) and container
    and evt.dir = <
    and not user.uid = 0
  output: >
    Privilege escalation attempt in container
    (user=%user.name user_uid=%user.uid
    proc=%proc.name cmdline=%proc.cmdline
    evt=%evt.type container_id=%container.id
    image=%container.image.repository
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, privilege_escalation, mitre_privilege_escalation, cks_lab]
EOF
```

## Bước 2: Cấu hình Falco file output

Chỉnh sửa `/etc/falco/falco.yaml` để bật file output:

```bash
sudo nano /etc/falco/falco.yaml
```

Tìm và sửa section `file_output`:

```yaml
# Falco file output configuration
file_output:
  enabled: true
  keep_alive: false
  filename: /tmp/falco-alerts.log
```

Snippet đầy đủ của section output trong `falco.yaml`:

```yaml
# Stdout output – in alert ra stdout
stdout_output:
  enabled: true

# File output – ghi alert ra file
file_output:
  enabled: true
  keep_alive: false
  filename: /tmp/falco-alerts.log

# Syslog output – ghi vào syslog (tùy chọn)
syslog_output:
  enabled: false

# JSON output – format JSON thay vì text (tùy chọn)
json_output: false
json_include_output_property: true
```

## Bước 3: Validate và restart Falco

```bash
# Validate rule file trước khi apply
sudo falco --validate /etc/falco/rules.d/behavioral-rules.yaml

# Restart Falco để load rule mới và cấu hình output
sudo systemctl restart falco

# Xác minh Falco đang chạy
sudo systemctl status falco
sudo systemctl is-active falco
```

## Bước 4: Trigger behaviors để tạo alert

```bash
# Sử dụng script trigger đã tạo
bash /tmp/trigger-behaviors.sh

# Hoặc trigger thủ công:

# Trigger 1: Đọc /etc/passwd
kubectl exec attacker-sim -n falco-behavioral-lab -- cat /etc/passwd

# Trigger 2: Đọc /etc/shadow
kubectl exec attacker-sim -n falco-behavioral-lab -- sh -c 'cat /etc/shadow 2>/dev/null || echo "no shadow"'

# Trigger 3: Outbound network connection
kubectl exec attacker-sim -n falco-behavioral-lab -- wget -q --timeout=3 http://1.1.1.1 -O /dev/null 2>/dev/null || true
```

## Bước 5: Verify alerts

```bash
# Xem toàn bộ alert log
cat /tmp/falco-alerts.log

# Tìm alert về file read
grep -i "shadow\|passwd\|Sensitive file" /tmp/falco-alerts.log

# Tìm alert về network
grep -i "outbound\|connect\|Unexpected" /tmp/falco-alerts.log

# Xem realtime
sudo tail -f /tmp/falco-alerts.log
```

Output mong đợi:

```
2024-10-15T10:30:45.123456789+0000: CRITICAL Sensitive file read in container
(user=root user_uid=0 file=/etc/passwd proc=cat cmdline=cat /etc/passwd
container_id=abc123 image=busybox
k8s_ns=falco-behavioral-lab k8s_pod=attacker-sim)

2024-10-15T10:30:47.456789012+0000: WARNING Unexpected outbound connection from container
(user=root proc=wget cmdline=wget -q --timeout=3 http://1.1.1.1 -O /dev/null
connection=10.0.0.5:45678->1.1.1.1:80 container_id=abc123 image=busybox
k8s_ns=falco-behavioral-lab k8s_pod=attacker-sim)
```

## Bước 6: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:

```
==========================================
 Lab 6.4 – Kiểm tra kết quả
==========================================

Kiểm tra tiêu chí 1: Falco service đang chạy
[PASS] Falco systemd service đang chạy (active)

Kiểm tra tiêu chí 2: File rule tùy chỉnh tồn tại tại /etc/falco/rules.d/
[PASS] Tìm thấy 1 file rule tùy chỉnh trong /etc/falco/rules.d
       Files: /etc/falco/rules.d/behavioral-rules.yaml

Kiểm tra tiêu chí 3: /tmp/falco-alerts.log tồn tại và chứa ít nhất 1 alert
[PASS] File /tmp/falco-alerts.log tồn tại và chứa 3 dòng alert

==========================================
 Kết quả: 3/3 tiêu chí đạt
==========================================
```

---

## Tóm tắt 3 Falco rule mẫu

| Rule | Condition | Priority | MITRE Tactic |
|------|-----------|----------|--------------|
| Sensitive File Read | `open_read and container and fd.name in (/etc/shadow, /etc/passwd)` | CRITICAL | Credential Access |
| Outbound Connection | `evt.type = connect and container and not fd.sip in (127.0.0.1)` | WARNING | Exfiltration |
| Privilege Escalation | `evt.type in (setuid, setgid) and container` | CRITICAL | Privilege Escalation |

## Falco filter fields quan trọng

| Field | Mô tả | Ví dụ |
|-------|-------|-------|
| `fd.name` | Đường dẫn file hoặc connection string | `/etc/shadow`, `10.0.0.1:80->1.1.1.1:443` |
| `fd.typechar` | Loại file descriptor | `f` (file), `4` (IPv4), `6` (IPv6) |
| `fd.sip` | Destination IP (server IP) | `1.1.1.1` |
| `proc.name` | Tên process | `cat`, `wget`, `bash` |
| `proc.cmdline` | Command line đầy đủ | `cat /etc/shadow` |
| `evt.type` | Loại syscall | `open`, `connect`, `setuid` |
| `container.id` | Container ID | `abc123def456` |
| `k8s.ns.name` | Kubernetes namespace | `falco-behavioral-lab` |
| `k8s.pod.name` | Kubernetes pod name | `attacker-sim` |

## Macro Falco hữu ích

```yaml
# Macro có sẵn trong Falco default rules
open_read: evt.type in (open, openat, openat2) and evt.is_open_read = true and fd.typechar = 'f'
container: container.id != host
spawned_process: evt.type = execve and evt.dir = <
interactive: proc.tty != 0
```
