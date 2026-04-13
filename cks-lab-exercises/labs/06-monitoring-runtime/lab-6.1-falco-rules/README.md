# Lab 6.1 – Falco Rules

**Domain:** Monitoring, Logging and Runtime Security (20%)
**Thời gian ước tính:** 25 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Viết Falco rule tùy chỉnh để phát hiện khi shell được spawn trong container
- Cấu hình Falco để load custom rule file
- Xác minh rule kích hoạt alert khi thực hiện `kubectl exec` vào container

---

## Bối cảnh

Bạn là kỹ sư bảo mật đang thiết lập hệ thống phát hiện xâm nhập runtime cho cluster Kubernetes. Một trong những dấu hiệu tấn công phổ biến nhất là kẻ tấn công spawn shell trong container để thực thi lệnh. Bạn cần cấu hình Falco để phát hiện hành vi này.

Nhiệm vụ của bạn là:
1. Tạo custom Falco rule phát hiện shell spawn trong container
2. Cấu hình Falco để load custom rule
3. Kích hoạt rule bằng cách `kubectl exec` vào container
4. Xác minh Falco ghi lại alert

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- `falco` đã được cài đặt (systemd service hoặc DaemonSet):
  - [https://falco.org/docs/getting-started/installation/](https://falco.org/docs/getting-started/installation/)
- Quyền truy cập node để đọc Falco logs

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Xem custom rule file đã được tạo

```bash
cat /tmp/custom-rules.yaml
```

### Bước 2: Hiểu cấu trúc Falco rule

Một Falco rule có cấu trúc:
```yaml
- rule: <tên rule>
  desc: <mô tả>
  condition: <điều kiện Falco filter>
  output: <format thông báo alert>
  priority: <mức độ ưu tiên>
  tags: [<tag1>, <tag2>]
```

### Bước 3: Chỉnh sửa custom rule (nếu cần)

```bash
# Xem và chỉnh sửa rule
nano /tmp/custom-rules.yaml
```

### Bước 4: Load custom rule vào Falco

```bash
# Nếu Falco chạy dưới dạng systemd service:
sudo cp /tmp/custom-rules.yaml /etc/falco/rules.d/custom-rules.yaml
sudo systemctl restart falco

# Nếu Falco chạy dưới dạng DaemonSet:
kubectl create configmap falco-custom-rules \
  --from-file=custom-rules.yaml=/tmp/custom-rules.yaml \
  -n falco --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart daemonset/falco -n falco
```

### Bước 5: Kích hoạt rule bằng kubectl exec

```bash
# Xem pod test trong namespace falco-lab
kubectl get pods -n falco-lab

# Exec vào pod để spawn shell
kubectl exec -it test-pod -n falco-lab -- /bin/sh

# Trong shell, chạy một lệnh rồi thoát
ls /
exit
```

### Bước 6: Kiểm tra Falco alert

```bash
# Nếu Falco chạy dưới dạng systemd:
sudo journalctl -u falco -f | grep "shell"
# Hoặc
sudo tail -f /var/log/falco.log | grep "shell"

# Nếu Falco chạy dưới dạng DaemonSet:
kubectl logs -n falco -l app=falco --tail=50 | grep "shell"
```

### Bước 7: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Falco đang chạy (systemd service hoặc DaemonSet pod)
- [ ] File `/tmp/custom-rules.yaml` tồn tại và chứa rule phát hiện shell spawn
- [ ] Namespace `falco-lab` tồn tại với pod test

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cấu trúc Falco rule phát hiện shell spawn</summary>

```yaml
- rule: Terminal shell in container
  desc: A shell was spawned in a container with an attached terminal
  condition: >
    spawned_process and container
    and shell_procs
    and proc.tty != 0
  output: >
    A shell was spawned in a container
    (user=%user.name user_loginuid=%user.loginuid
    %container.info
    shell=%proc.name parent=%proc.pname
    cmdline=%proc.cmdline terminal=%proc.tty
    container_id=%container.id image=%container.image.repository)
  priority: WARNING
  tags: [container, shell, mitre_execution]
```

Các macro hữu ích:
- `spawned_process`: process mới được tạo
- `container`: đang chạy trong container
- `shell_procs`: process là shell (bash, sh, zsh, v.v.)
- `proc.tty != 0`: có terminal đính kèm

</details>

<details>
<summary>Gợi ý 2: Kiểm tra Falco đang chạy</summary>

```bash
# Kiểm tra systemd service
systemctl status falco

# Kiểm tra DaemonSet
kubectl get daemonset -n falco
kubectl get pods -n falco

# Kiểm tra version
falco --version
```

</details>

<details>
<summary>Gợi ý 3: Cài đặt Falco bằng Helm</summary>

```bash
# Thêm Helm repo
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Cài đặt Falco
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set driver.kind=ebpf

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

### Falco hoạt động như thế nào?

Falco là một runtime security tool sử dụng kernel-level monitoring để phát hiện hành vi bất thường:
1. **Kernel module hoặc eBPF probe**: Intercept system calls ở kernel level
2. **Rules engine**: So sánh system calls với các rule đã định nghĩa
3. **Alert**: Ghi log hoặc gửi notification khi rule match

### Tại sao phát hiện shell spawn quan trọng?

Shell spawn trong container là dấu hiệu của:
- **Container escape attempt**: Kẻ tấn công cố gắng thoát khỏi container
- **Lateral movement**: Di chuyển sang container/node khác
- **Data exfiltration**: Đọc và gửi dữ liệu nhạy cảm
- **Persistence**: Cài đặt backdoor

### Falco rule conditions

Falco sử dụng ngôn ngữ filter riêng:
- `evt.type = execve`: System call execve (tạo process mới)
- `container.id != host`: Đang trong container
- `proc.name in (bash, sh, zsh)`: Process là shell
- `fd.typechar = 'f'`: File descriptor là file

### Best practices cho Falco rules

- Bắt đầu với rules có sẵn trong `/etc/falco/falco_rules.yaml`
- Tạo custom rules trong `/etc/falco/rules.d/` để không bị ghi đè khi update
- Dùng `priority: WARNING` hoặc `CRITICAL` cho rules quan trọng
- Tích hợp với SIEM (Splunk, Elasticsearch) để phân tích tập trung

---

## Tham khảo

- [Falco Documentation](https://falco.org/docs/)
- [Falco Rules Reference](https://falco.org/docs/rules/)
- [Falco Default Rules](https://github.com/falcosecurity/rules)
- [CKS Exam – Monitoring, Logging and Runtime Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
