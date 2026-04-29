# Cheatsheet 06 – Monitoring, Logging & Runtime Security (20%)

## Falco

### Falco rule syntax
```yaml
- rule: <rule-name>
  desc: <description>
  condition: <condition-expression>
  output: <output-format>
  priority: <EMERGENCY|ALERT|CRITICAL|ERROR|WARNING|NOTICE|INFORMATIONAL|DEBUG>
  tags: [<tag1>, <tag2>]
```

### Key macros and fields
```yaml
# Common macros
spawned_process        # A new process was spawned
container              # Event is in a container
interactive            # Process has a terminal (tty)
shell_procs            # Process is a shell (bash, sh, zsh, etc.)
k8s_containers         # Kubernetes containers
sensitive_files        # Sensitive file paths (/etc/shadow, /etc/passwd, etc.)

# Common fields
proc.name              # Process name
proc.cmdline           # Full command line
proc.pname             # Parent process name
container.id           # Container ID
container.name         # Container name
k8s.pod.name           # Pod name
k8s.ns.name            # Namespace name
user.name              # User name
fd.name                # File descriptor name (file path)
evt.type               # Event type (execve, open, connect, etc.)
```

### Common Falco rules

#### Detect shell spawned in container
```yaml
- rule: Terminal Shell in Container
  desc: A shell was spawned in a container with an attached terminal
  condition: >
    spawned_process
    and container
    and shell_procs
    and proc.tty != 0
  output: >
    Shell spawned in container
    (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
     container=%container.name shell=%proc.name
     parent=%proc.pname cmdline=%proc.cmdline)
  priority: WARNING
  tags: [container, shell, mitre_execution]
```

#### Detect kubectl exec
```yaml
- rule: Kubectl Exec into Pod
  desc: Detect kubectl exec into a running pod
  condition: >
    spawned_process
    and container
    and proc.name in (sh, bash, zsh, dash)
    and proc.pname in (runc, containerd-shim, docker-runc)
  output: >
    Exec into pod detected
    (pod=%k8s.pod.name ns=%k8s.ns.name
     container=%container.name user=%user.name
     cmdline=%proc.cmdline)
  priority: WARNING
```

#### Detect write to sensitive file
```yaml
- rule: Write to Sensitive File
  desc: Detect writes to sensitive files
  condition: >
    open_write
    and sensitive_files
    and not proc.name in (known_write_procs)
  output: >
    Sensitive file write
    (user=%user.name file=%fd.name
     pod=%k8s.pod.name container=%container.name)
  priority: ERROR
```

### Falco commands
```bash
# Check Falco service status
systemctl status falco

# View Falco logs
journalctl -u falco -f
tail -f /var/log/falco/falco.log

# Test a rule file
falco -r /etc/falco/rules.d/my-rules.yaml --dry-run

# Reload rules without restart
kill -1 $(pidof falco)

# List loaded rules
falco --list

# Run Falco with custom rules
falco -r /etc/falco/falco_rules.yaml -r /etc/falco/rules.d/custom.yaml
```

### Falco config paths
```
/etc/falco/falco.yaml              # Main config
/etc/falco/falco_rules.yaml        # Default rules
/etc/falco/falco_rules.local.yaml  # Local overrides
/etc/falco/rules.d/                # Additional rules directory
```

---

## Audit Log Analysis with jq

### Audit log event structure
```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "RequestResponse",
  "auditID": "...",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/default/secrets/my-secret",
  "verb": "get",
  "user": {"username": "admin", "groups": ["system:masters"]},
  "sourceIPs": ["192.168.1.1"],
  "responseStatus": {"code": 200},
  "objectRef": {
    "resource": "secrets",
    "namespace": "default",
    "name": "my-secret"
  },
  "requestReceivedTimestamp": "2024-01-15T10:00:00Z"
}
```

### jq queries for audit log analysis

```bash
# Find all Secret access events
cat audit.log | jq 'select(.objectRef.resource=="secrets") | {user: .user.username, verb: .verb, secret: .objectRef.name, ns: .objectRef.namespace, time: .requestReceivedTimestamp}'

# Find who accessed a specific secret
cat audit.log | jq 'select(.objectRef.resource=="secrets" and .objectRef.name=="my-secret") | {user: .user.username, verb: .verb, time: .requestReceivedTimestamp}'

# Find all 403 Forbidden responses
cat audit.log | jq 'select(.responseStatus.code==403) | {user: .user.username, verb: .verb, resource: .objectRef.resource, uri: .requestURI, time: .requestReceivedTimestamp}'

# Find all exec events (kubectl exec)
cat audit.log | jq 'select(.requestURI | test("/exec")) | {user: .user.username, pod: .objectRef.name, ns: .objectRef.namespace, time: .requestReceivedTimestamp}'

# Find all events by a specific user
cat audit.log | jq 'select(.user.username=="suspicious-user") | {verb: .verb, resource: .objectRef.resource, name: .objectRef.name, time: .requestReceivedTimestamp}'

# Count events by verb
cat audit.log | jq -r '.verb' | sort | uniq -c | sort -rn

# Find delete operations
cat audit.log | jq 'select(.verb=="delete") | {user: .user.username, resource: .objectRef.resource, name: .objectRef.name, time: .requestReceivedTimestamp}'

# Find anonymous requests
cat audit.log | jq 'select(.user.username=="system:anonymous") | {verb: .verb, uri: .requestURI, ip: .sourceIPs[0]}'

# Find all pod exec/attach events
cat audit.log | jq 'select(.objectRef.resource=="pods" and (.objectRef.subresource=="exec" or .objectRef.subresource=="attach")) | {user: .user.username, pod: .objectRef.name, ns: .objectRef.namespace, time: .requestReceivedTimestamp}'
```

---

## AuditPolicy with Log Backend

### AuditPolicy YAML (full template)
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived    # Skip early stage to reduce log volume
rules:
# Log Secret operations at RequestResponse level
- level: RequestResponse
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["secrets"]

# Log pod exec/attach at RequestResponse
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods/exec", "pods/attach", "pods/portforward"]

# Log authentication failures
- level: Metadata
  omitStages:
  - RequestReceived
  users: ["system:anonymous"]

# Log all other resource operations at Metadata
- level: Metadata
  resources:
  - group: ""
    resources: ["pods", "services", "configmaps", "namespaces"]
  - group: "apps"
    resources: ["deployments", "replicasets", "daemonsets"]
  - group: "rbac.authorization.k8s.io"
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]

# Don't log read-only system component requests
- level: None
  users:
  - system:kube-scheduler
  - system:kube-controller-manager
  verbs: ["get", "list", "watch"]

# Default: log everything else at Metadata
- level: Metadata
```

### kube-apiserver flags for audit logging
```bash
# Add to /etc/kubernetes/manifests/kube-apiserver.yaml spec.containers[0].command:
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit/audit.log
--audit-log-maxage=30          # Days to retain
--audit-log-maxbackup=10       # Number of backup files
--audit-log-maxsize=100        # MB per file before rotation
```

### Mount audit policy in static pod
```yaml
# In kube-apiserver.yaml, add to volumeMounts:
- mountPath: /etc/kubernetes/audit-policy.yaml
  name: audit-policy
  readOnly: true
- mountPath: /var/log/kubernetes/audit/
  name: audit-log

# Add to volumes:
- hostPath:
    path: /etc/kubernetes/audit-policy.yaml
    type: File
  name: audit-policy
- hostPath:
    path: /var/log/kubernetes/audit/
    type: DirectoryOrCreate
  name: audit-log
```

---

## Immutable Containers (readOnlyRootFilesystem + emptyDir)

### Pod template with immutable filesystem
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-pod
spec:
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      runAsUser: 101
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp-dir
      mountPath: /tmp
    - name: var-run
      mountPath: /var/run
    - name: var-cache-nginx
      mountPath: /var/cache/nginx
    - name: var-log-nginx
      mountPath: /var/log/nginx
  volumes:
  - name: tmp-dir
    emptyDir: {}
  - name: var-run
    emptyDir: {}
  - name: var-cache-nginx
    emptyDir: {}
  - name: var-log-nginx
    emptyDir: {}
```

### Verify immutability
```bash
# Try to write to root filesystem (should fail)
kubectl exec <pod> -- touch /test-file
# Expected: touch: /test-file: Read-only file system

# Write to emptyDir (should succeed)
kubectl exec <pod> -- touch /tmp/test-file
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Check Falco status | `systemctl status falco` |
| View Falco alerts | `journalctl -u falco -f` |
| Test Falco rules | `falco -r /path/to/rules.yaml --dry-run` |
| Find secret access in audit log | `jq 'select(.objectRef.resource=="secrets")'` |
| Find 403 errors | `jq 'select(.responseStatus.code==403)'` |
| Find exec events | `jq 'select(.requestURI \| test("/exec"))'` |
| Verify read-only FS | `kubectl exec <pod> -- touch /test` |
| Check audit log | `tail -f /var/log/kubernetes/audit/audit.log \| jq .` |

---

## Falco Advanced Rules (Behavioral Analytics)

### Syscall event types quan trọng

```yaml
# File access
open_read: evt.type in (open, openat, openat2) and evt.is_open_read = true
open_write: evt.type in (open, openat, openat2) and evt.is_open_write = true

# Process
spawned_process: evt.type = execve and evt.dir = <

# Network
evt.type = connect    # Outbound connection
evt.type = accept     # Inbound connection

# Privilege escalation
evt.type in (setuid, setgid)
```

### fd.name filter (file path)

```yaml
# Phát hiện đọc file credential nhạy cảm
condition: open_read and container and fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers)

# Phát hiện ghi vào thư mục hệ thống
condition: open_write and container and fd.name startswith /etc/
```

### proc.name filter (process name)

```yaml
# Phát hiện shell spawn
condition: spawned_process and container and proc.name in (bash, sh, zsh, dash)

# Phát hiện network tools
condition: spawned_process and container and proc.name in (curl, wget, nc, nmap)
```

### Network egress detection

```yaml
- rule: Unexpected Outbound Connection
  desc: Detect outbound network connection from container
  condition: >
    evt.type = connect and container
    and not fd.sip in (127.0.0.1, ::1)
    and fd.typechar = 4
  output: >
    Outbound connection (proc=%proc.name fd=%fd.name
    container=%container.id pod=%k8s.pod.name ns=%k8s.ns.name)
  priority: WARNING
  tags: [network, container, mitre_exfiltration]
```

### Sensitive file read detection

```yaml
- rule: Sensitive File Read in Container
  desc: Detect reading of sensitive credential files
  condition: >
    open_read and container
    and fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers)
  output: >
    Sensitive file read (user=%user.name file=%fd.name
    proc=%proc.name container=%container.id pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, credential_access, mitre_credential_access]
```

### Privilege escalation detection

```yaml
- rule: Setuid or Setgid in Container
  desc: Detect privilege escalation via setuid/setgid
  condition: >
    evt.type in (setuid, setgid) and container
    and evt.dir = <
  output: >
    Privilege escalation (user=%user.name proc=%proc.name
    evt=%evt.type container=%container.id pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, privilege_escalation, mitre_privilege_escalation]
```

### Cấu hình Falco file output

```yaml
# /etc/falco/falco.yaml
file_output:
  enabled: true
  keep_alive: false
  filename: /tmp/falco-alerts.log

# JSON output (tùy chọn)
json_output: false
```

### Falco filter fields quan trọng

| Field | Mô tả | Ví dụ |
|-------|-------|-------|
| `fd.name` | Đường dẫn file hoặc connection | `/etc/shadow`, `10.0.0.1:80` |
| `fd.typechar` | Loại fd: `f`=file, `4`=IPv4, `6`=IPv6 | `4` |
| `fd.sip` | Destination IP | `1.1.1.1` |
| `proc.name` | Tên process | `cat`, `wget` |
| `proc.cmdline` | Command line đầy đủ | `cat /etc/shadow` |
| `evt.type` | Loại syscall | `open`, `connect`, `setuid` |
| `container.id` | Container ID | `abc123` |
| `k8s.ns.name` | Kubernetes namespace | `default` |
| `k8s.pod.name` | Kubernetes pod name | `my-pod` |
| `user.name` | Username | `root` |
| `user.uid` | User UID | `0` |

### Quick Reference – Falco Advanced

| Task | Command |
|------|---------|
| Validate rule file | `sudo falco --validate /etc/falco/rules.d/my-rules.yaml` |
| Restart Falco | `sudo systemctl restart falco` |
| View Falco alerts | `cat /tmp/falco-alerts.log` |
| Tail alerts realtime | `sudo tail -f /tmp/falco-alerts.log` |
| View Falco logs | `sudo journalctl -u falco -f` |
| Check Falco status | `systemctl is-active falco` |
| List loaded rules | `falco --list` |
| Falco DaemonSet logs | `kubectl logs -n falco -l app=falco --tail=50` |
