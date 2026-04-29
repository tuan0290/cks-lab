# Solution: Lab 6.4 - Falco Custom Rules - Privileged Container Detection

## Overview

This solution demonstrates how to create Falco rules to detect privileged containers and dangerous capability usage.

## Step-by-Step Solution

### Step 1: Create the Falco rules file

Create `falco-privileged-rules.yaml`:

```yaml
# falco-privileged-rules.yaml

# Macro for known legitimate privileged containers
- macro: known_privileged_containers
  condition: >
    container.image.repository in (
      falcosecurity/falco,
      falco-no-driver,
      kindest/node,
      calico/node,
      cilium/cilium,
      weave-npc,
      quay.io/cilium/cilium
    )

# Rule 1: Detect privileged container startup
- rule: Detect Privileged Container
  desc: Detect startup of a privileged container
  condition: >
    container.privileged=true and
    not known_privileged_containers and
    container.name != "host"
  output: >
    Privileged container started (user=%user.name container=%container.name
    image=%container.image.repository pod=%k8s.pod.name
    namespace=%k8s.ns.name)
  priority: WARNING
  tags: [container, privilege, cks]

# Rule 2: Detect dangerous capabilities
- rule: Detect Dangerous Capabilities
  desc: Detect container with dangerous Linux capabilities
  condition: >
    spawned_process and
    container and
    (proc.cap_effective contains CAP_SYS_ADMIN or
     proc.cap_effective contains CAP_NET_ADMIN or
     proc.cap_effective contains CAP_SYS_PTRACE or
     proc.cap_effective contains CAP_SYS_MODULE)
  output: >
    Container with dangerous capabilities (user=%user.name
    container=%container.name image=%container.image.repository
    capabilities=%proc.cap_effective pod=%k8s.pod.name)
  priority: WARNING
  tags: [container, capabilities, cks]

# Rule 3: Detect privilege escalation via setuid
- rule: Detect Setuid Execution
  desc: Detect execution of setuid binaries in containers
  condition: >
    spawned_process and
    container and
    proc.is_suid_exe=true and
    not proc.name in (sudo, su, newgrp, sg)
  output: >
    Setuid binary executed in container (user=%user.name
    command=%proc.cmdline container=%container.name
    image=%container.image.repository)
  priority: WARNING
  tags: [container, privilege, setuid, cks]
```

### Step 2: Deploy as ConfigMap

```bash
kubectl create configmap falco-privileged-rules \
  --from-file=falco-privileged-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 3: Verify ConfigMap content

```bash
kubectl get configmap falco-privileged-rules -n falco -o yaml
```

### Step 4: Restart Falco to load rules

```bash
kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco --timeout=120s
```

### Step 5: Test the rules

```bash
# The privileged-test pod from setup.sh should have triggered the rule
# Check Falco logs
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=100 | grep -i "privileged"

# Create another privileged pod to test
kubectl run priv-test-2 \
  --image=busybox:1.35 \
  --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"priv-test-2","image":"busybox:1.35","command":["sleep","60"],"securityContext":{"privileged":true}}]}}' \
  -n lab-6-4

sleep 5
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i "privileged"
```

## Key Concepts

### Privileged Container vs Capabilities

| Feature | Privileged Container | Dangerous Capabilities |
|---------|---------------------|----------------------|
| Detection field | `container.privileged=true` | `proc.cap_effective` |
| Risk level | Highest - full host access | High - specific privileges |
| Common use | Legacy apps, debugging | Network tools, system admin |

### Important Falco Fields for Privilege Detection

| Field | Description |
|-------|-------------|
| `container.privileged` | True if container runs in privileged mode |
| `proc.cap_effective` | Effective capabilities of the process |
| `proc.is_suid_exe` | True if process is a setuid binary |
| `k8s.pod.name` | Kubernetes pod name |
| `k8s.ns.name` | Kubernetes namespace |

## Common Mistakes

1. **No exclusions**: Always exclude known legitimate privileged containers (Falco, CNI plugins)
2. **Wrong field name**: Use `container.privileged` not `container.is_privileged`
3. **Missing pod context**: Include `k8s.pod.name` and `k8s.ns.name` for better incident response
4. **Too broad capability check**: Be specific about which capabilities are dangerous

## CKS Exam Tips

- Know that `container.privileged=true` is the key Falco field for privileged detection
- Understand that privileged containers bypass all Linux security mechanisms
- Remember to exclude system containers (Falco, CNI, CSI drivers) from alerts
- The `proc.cap_effective` field lists all effective capabilities
