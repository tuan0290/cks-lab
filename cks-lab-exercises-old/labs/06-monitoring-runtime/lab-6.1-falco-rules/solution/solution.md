# Giải pháp – Lab 6.1 Falco Rules

## Bước 1: Xem custom rule file

```bash
cat /tmp/custom-rules.yaml
```

Nội dung rule phát hiện shell spawn:
```yaml
- rule: Detect Shell Spawned in Container
  desc: Phát hiện khi shell được spawn trong container
  condition: >
    spawned_process and container
    and proc.name in (shell_binaries)
  output: >
    Shell spawned in container
    (user=%user.name container_id=%container.id
    container_name=%container.name
    image=%container.image.repository:%container.image.tag
    shell=%proc.name parent=%proc.pname
    cmdline=%proc.cmdline
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: WARNING
  tags: [container, shell, mitre_execution]

- list: shell_binaries
  items: [bash, sh, zsh, ksh, fish, tcsh, csh, dash]

- rule: Detect Interactive Shell in Container
  desc: Phát hiện shell tương tác (có terminal) trong container
  condition: >
    spawned_process and container
    and proc.name in (shell_binaries)
    and proc.tty != 0
  output: >
    Interactive shell spawned in container
    (user=%user.name container_id=%container.id
    shell=%proc.name terminal=%proc.tty
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, shell, interactive, mitre_execution]
```

## Bước 2: Load custom rule vào Falco

### Nếu Falco chạy dưới dạng systemd service:

```bash
# Copy rule file vào thư mục rules.d
sudo cp /tmp/custom-rules.yaml /etc/falco/rules.d/custom-rules.yaml

# Restart Falco để load rule mới
sudo systemctl restart falco

# Xác minh Falco đang chạy
sudo systemctl status falco
```

### Nếu Falco chạy dưới dạng DaemonSet:

```bash
# Tạo ConfigMap từ rule file
kubectl create configmap falco-custom-rules \
  --from-file=custom-rules.yaml=/tmp/custom-rules.yaml \
  -n falco --dry-run=client -o yaml | kubectl apply -f -

# Cấu hình Falco để load ConfigMap (nếu dùng Helm)
helm upgrade falco falcosecurity/falco \
  --namespace falco \
  --set customRules."custom-rules\.yaml"="$(cat /tmp/custom-rules.yaml)"

# Hoặc restart DaemonSet để reload
kubectl rollout restart daemonset/falco -n falco

# Chờ DaemonSet sẵn sàng
kubectl rollout status daemonset/falco -n falco
```

## Bước 3: Kích hoạt rule bằng kubectl exec

```bash
# Xem pod test trong namespace falco-lab
kubectl get pods -n falco-lab

# Exec vào pod để spawn shell
kubectl exec -it test-pod -n falco-lab -- /bin/sh

# Trong shell, chạy một số lệnh
ls /
cat /etc/hostname
exit
```

## Bước 4: Kiểm tra Falco alert

### Nếu Falco là systemd service:

```bash
# Xem logs realtime
sudo journalctl -u falco -f

# Tìm alert về shell
sudo journalctl -u falco --since "5 minutes ago" | grep -i "shell\|spawned"

# Hoặc xem log file
sudo tail -f /var/log/falco.log | grep -i shell
```

### Nếu Falco là DaemonSet:

```bash
# Xem logs của Falco pod trên node đang chạy test-pod
NODE=$(kubectl get pod test-pod -n falco-lab -o jsonpath='{.spec.nodeName}')
FALCO_POD=$(kubectl get pods -n falco -l app=falco -o jsonpath="{.items[?(@.spec.nodeName=='${NODE}')].metadata.name}")
kubectl logs $FALCO_POD -n falco --tail=50 | grep -i "shell\|spawned"
```

Output mong đợi:
```
2024-01-15T10:30:45.123456789+0000: CRITICAL Interactive shell spawned in container
(user=root container_id=abc123 container_name=app
image=nginx:1.25-alpine shell=sh terminal=34816
k8s_ns=falco-lab k8s_pod=test-pod)
```

## Bước 5: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] Falco DaemonSet đang chạy trong namespace 'falco' (1/1 pods ready)
[PASS] File /tmp/custom-rules.yaml tồn tại và chứa shell spawn detection rule
[PASS] Namespace 'falco-lab' tồn tại và pod 'test-pod' đang Running
---
Kết quả: 3/3 tiêu chí đạt
```

## Tóm tắt Falco rule syntax

| Field | Mô tả | Ví dụ |
|-------|-------|-------|
| `rule` | Tên rule | `Terminal shell in container` |
| `desc` | Mô tả ngắn | `A shell was spawned...` |
| `condition` | Filter expression | `spawned_process and container` |
| `output` | Format thông báo | `Shell spawned (%container.id)` |
| `priority` | Mức độ ưu tiên | `WARNING`, `CRITICAL`, `ERROR` |
| `tags` | Tags phân loại | `[container, shell]` |

## Các macro Falco hữu ích

```yaml
# Macro có sẵn trong Falco
spawned_process: evt.type = execve and evt.dir = <
container: container.id != host
interactive: proc.tty != 0
shell_procs: proc.name in (bash, sh, zsh, ksh)

# Field phổ biến
container.id          # Container ID
container.name        # Container name
container.image.repository  # Image name
k8s.ns.name          # Kubernetes namespace
k8s.pod.name         # Pod name
proc.name            # Process name
proc.cmdline         # Full command line
proc.pname           # Parent process name
user.name            # User name
proc.tty             # Terminal (0 = no terminal)
```

## Kiểm tra rule syntax

```bash
# Validate rule file trước khi apply
falco --validate /tmp/custom-rules.yaml

# Chạy Falco với custom rule (test mode)
falco -r /tmp/custom-rules.yaml --dry-run
```
