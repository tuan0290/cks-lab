# Cheatsheet 03 – System Hardening (10%)

## AppArmor

### Commands
```bash
# Check AppArmor status and loaded profiles
aa-status
sudo aa-status

# Load a profile
sudo apparmor_parser -r -W /etc/apparmor.d/<profile-name>

# Load profile from custom path
sudo apparmor_parser -r -W /path/to/profile

# Set profile to enforce mode
sudo aa-enforce /etc/apparmor.d/<profile-name>

# Set profile to complain mode (log but don't block)
sudo aa-complain /etc/apparmor.d/<profile-name>

# Disable a profile
sudo aa-disable /etc/apparmor.d/<profile-name>

# List loaded profiles
sudo aa-status | grep "profiles are loaded"

# Check if a specific profile is loaded
sudo aa-status | grep <profile-name>
```

### AppArmor profile example
```
#include <tunables/global>

profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,
  network,

  # Deny write to filesystem
  deny /** w,
  deny /** wl,
}
```

### Apply AppArmor profile to Pod (annotation syntax)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod
  annotations:
    # Format: container.apparmor.security.beta.kubernetes.io/<container-name>: <profile>
    container.apparmor.security.beta.kubernetes.io/mycontainer: localhost/k8s-deny-write
spec:
  containers:
  - name: mycontainer
    image: nginx:1.25
```

### AppArmor profile values
| Value | Description |
|-------|-------------|
| `runtime/default` | Use container runtime's default profile |
| `localhost/<profile-name>` | Use profile loaded on the node |
| `unconfined` | No AppArmor restrictions |

### Kubernetes 1.30+ native AppArmor (securityContext)
```yaml
spec:
  containers:
  - name: mycontainer
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-deny-write
```

---

## Seccomp

### Profile path on node
```
/var/lib/kubelet/seccomp/profiles/
```

### Seccomp profile JSON example
```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "accept4", "bind", "brk", "capget", "capset", "chdir",
        "clone", "close", "connect", "dup2", "epoll_create1",
        "epoll_ctl", "epoll_wait", "execve", "exit", "exit_group",
        "fchown", "fcntl", "fstat", "futex", "getdents64",
        "getpid", "getppid", "getuid", "listen", "lstat",
        "mmap", "mprotect", "munmap", "nanosleep", "open",
        "openat", "pipe2", "poll", "prctl", "read", "recvfrom",
        "recvmsg", "rt_sigaction", "rt_sigprocmask", "rt_sigreturn",
        "sendmsg", "sendto", "set_tid_address", "setgid", "setuid",
        "socket", "stat", "uname", "wait4", "write", "writev"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

### Apply Seccomp profile to Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-pod
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/my-profile.json  # relative to /var/lib/kubelet/seccomp/
  containers:
  - name: app
    image: nginx:1.25
```

### Seccomp profile types
| Type | Description |
|------|-------------|
| `RuntimeDefault` | Container runtime's default seccomp profile |
| `Localhost` | Custom profile from node filesystem |
| `Unconfined` | No seccomp restrictions |

---

## SecurityContext (Full Template)

### Pod-level + Container-level SecurityContext
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE   # Only add if strictly needed
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: varrun
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: varrun
    emptyDir: {}
```

### SecurityContext field reference
| Field | Level | Description |
|-------|-------|-------------|
| `runAsNonRoot: true` | Pod/Container | Reject if UID=0 |
| `runAsUser: <uid>` | Pod/Container | Set UID |
| `runAsGroup: <gid>` | Pod/Container | Set GID |
| `fsGroup: <gid>` | Pod | Volume ownership GID |
| `allowPrivilegeEscalation: false` | Container | Block setuid/setgid |
| `readOnlyRootFilesystem: true` | Container | Immutable root FS |
| `capabilities.drop: [ALL]` | Container | Drop all Linux capabilities |
| `capabilities.add: [NET_BIND_SERVICE]` | Container | Add specific capability |
| `privileged: false` | Container | No privileged mode |
| `seccompProfile.type: RuntimeDefault` | Pod/Container | Apply seccomp |

---

## Quick Reference

| Task | Command |
|------|---------|
| Check AppArmor status | `aa-status` |
| Load AppArmor profile | `apparmor_parser -r -W /etc/apparmor.d/<profile>` |
| Enforce AppArmor profile | `aa-enforce /etc/apparmor.d/<profile>` |
| Complain mode | `aa-complain /etc/apparmor.d/<profile>` |
| Seccomp profiles path | `/var/lib/kubelet/seccomp/profiles/` |
| Check pod seccomp | `kubectl get pod <name> -o jsonpath='{.spec.securityContext.seccompProfile}'` |
| Check pod AppArmor annotation | `kubectl get pod <name> -o jsonpath='{.metadata.annotations}'` |
| Verify non-root | `kubectl exec <pod> -- id` |
| Check capabilities | `kubectl exec <pod> -- cat /proc/1/status \| grep Cap` |

---

## OS Footprint (Minimize Attack Surface)

### Liệt kê package đã cài đặt

```bash
# Debian/Ubuntu
dpkg --list
dpkg --list | grep -E "telnet|nmap|netcat|wireshark"

# RHEL/CentOS
rpm -qa
rpm -qa | grep -E "telnet|nmap|netcat"
```

### Xóa package không cần thiết

```bash
# Debian/Ubuntu
sudo apt-get remove --purge telnet nmap netcat-openbsd
sudo apt-get autoremove

# RHEL/CentOS
sudo yum remove telnet nmap nc
```

### Kiểm tra và disable service không cần thiết

```bash
# Xem tất cả service đang chạy
systemctl list-units --type=service --state=running

# Xem tất cả service đang enabled
systemctl list-unit-files --type=service --state=enabled

# Disable và stop service
sudo systemctl disable --now snapd
sudo systemctl disable --now bluetooth
sudo systemctl disable --now avahi-daemon
sudo systemctl disable --now cups
sudo systemctl disable --now rpcbind

# Xác minh service đã disabled
systemctl is-enabled snapd    # → disabled
systemctl is-active snapd     # → inactive
```

### Kiểm tra port đang lắng nghe

```bash
# ss (thay thế netstat)
ss -tlnp          # TCP listening ports
ss -ulnp          # UDP listening ports
ss -tlnp | grep LISTEN

# Ghi kết quả vào file
ss -tlnp > /tmp/open-ports.txt

# netstat (nếu có)
netstat -tlnp
```

### Service thường cần disable trên Kubernetes node

| Service | Lý do |
|---------|-------|
| `snapd` | Package manager không cần thiết trên server |
| `bluetooth` | Không cần thiết trên server/VM |
| `avahi-daemon` | mDNS/DNS-SD, không cần thiết |
| `cups` | Print service, không cần thiết |
| `rpcbind` | RPC portmapper, không cần nếu không dùng NFS |
| `postfix` | Mail server, không cần thiết |

### Quick Reference – OS Footprint

| Task | Command |
|------|---------|
| List installed packages | `dpkg --list` / `rpm -qa` |
| Find unnecessary packages | `dpkg --list \| grep -E "telnet\|nmap\|netcat"` |
| List running services | `systemctl list-units --type=service --state=running` |
| Disable service | `sudo systemctl disable --now <service>` |
| Check service status | `systemctl is-enabled <service>` |
| Check open ports | `ss -tlnp` |
| Save port list | `ss -tlnp > /tmp/open-ports.txt` |
