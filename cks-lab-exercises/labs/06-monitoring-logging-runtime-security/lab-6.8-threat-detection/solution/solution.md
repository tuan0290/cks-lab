# Solution: Lab 6.8 - Threat Detection - Attack Simulation and Response

## Overview

This solution demonstrates how to detect and respond to common Kubernetes attack scenarios using Falco and audit log analysis.

## Attack Scenarios and Detection

### Scenario A: Shell Spawning Detection

**Attack**: Attacker gains shell access to a container.

**Detection Rule**:
```yaml
- rule: Shell Spawned in Container
  desc: Detect shell process spawned inside a container
  condition: >
    spawned_process and container and shell_procs and not known_shell_spawners
  output: >
    Shell spawned in container (user=%user.name shell=%proc.name
    parent=%proc.pname cmdline=%proc.cmdline container=%container.name
    image=%container.image.repository pod=%k8s.pod.name namespace=%k8s.ns.name)
  priority: WARNING
  tags: [shell, container, cks]

- macro: shell_procs
  condition: proc.name in (bash, sh, zsh, ksh, fish, dash)

- macro: known_shell_spawners
  condition: >
    proc.pname in (containerd-shim, runc, docker-init) or
    container.image.repository in (docker.io/library/alpine, docker.io/library/ubuntu)
```

**Simulation**:
```bash
ATTACKER=$(kubectl get pod -n lab-6-8 -l role=attacker -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n lab-6-8 $ATTACKER -- /bin/sh -c "id && hostname"
```

### Scenario B: Sensitive File Access

**Attack**: Attacker reads `/etc/shadow` to extract password hashes.

**Detection Rule**:
```yaml
- rule: Detect Sensitive File Access
  desc: Detect read access to sensitive system files
  condition: >
    open_read and
    fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers) and
    not proc.name in (sshd, login, systemd-logind)
  output: >
    Sensitive file accessed (user=%user.name command=%proc.cmdline
    file=%fd.name container=%container.name)
  priority: WARNING
  tags: [filesystem, security, cks]
```

**Simulation**:
```bash
kubectl exec -n lab-6-8 $ATTACKER -- cat /etc/shadow 2>/dev/null || true
kubectl exec -n lab-6-8 $ATTACKER -- cat /etc/passwd
```

### Scenario C: Unexpected Outbound Connection

**Attack**: Attacker exfiltrates data to external server.

**Detection Rule**:
```yaml
- rule: Unexpected Outbound Connection
  desc: Detect unexpected outbound network connection from container
  condition: >
    outbound and container and
    not fd.sport in (80, 443, 53, 8080, 8443) and
    not known_outbound_destinations
  output: >
    Unexpected outbound connection (user=%user.name command=%proc.cmdline
    connection=%fd.name container=%container.name)
  priority: WARNING
  tags: [network, container, cks]

- macro: known_outbound_destinations
  condition: fd.sip in (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
```

### Scenario D: Container Escape Attempt

**Attack**: Attacker tries to access host filesystem via /proc.

**Detection Rule**:
```yaml
- rule: Container Escape via Proc
  desc: Detect attempt to access host /proc filesystem
  condition: >
    open_read and container and
    fd.name startswith /proc/1/ and
    not proc.name in (ps, top, htop)
  output: >
    Container escape attempt via /proc (user=%user.name
    command=%proc.cmdline file=%fd.name container=%container.name)
  priority: CRITICAL
  tags: [container, escape, cks]
```

## Complete Deployment

### Step 1: Create and deploy all rules

```bash
cat > falco-threat-detection-rules.yaml << 'EOF'
# [Include all rules from above]
EOF

kubectl create configmap falco-threat-detection \
  --from-file=falco-threat-detection-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco
```

### Step 2: Run attack simulations

```bash
ATTACKER=$(kubectl get pod -n lab-6-8 -l role=attacker -o jsonpath='{.items[0].metadata.name}')

# Scenario A: Shell spawning
kubectl exec -n lab-6-8 $ATTACKER -- /bin/sh -c "echo 'attack simulation'"

# Scenario B: Sensitive file access
kubectl exec -n lab-6-8 $ATTACKER -- cat /etc/passwd

# Check Falco alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50 | grep -E "WARNING|CRITICAL"
```

### Step 3: Audit log analysis

```bash
AUDIT_LOG="/var/log/kubernetes/audit.log"

if [ -f "$AUDIT_LOG" ]; then
    # Find exec events
    echo "=== kubectl exec events ==="
    grep '"subresource":"exec"' "$AUDIT_LOG" | \
        jq '{time: .requestReceivedTimestamp, user: .user.username, pod: .objectRef.name}' | \
        tail -5

    # Find secret access
    echo "=== Secret access events ==="
    grep '"resource":"secrets"' "$AUDIT_LOG" | \
        jq 'select(.stage=="ResponseComplete") | {time: .requestReceivedTimestamp, user: .user.username, verb: .verb}' | \
        tail -5

    # Find failed requests
    echo "=== Failed requests (403/401) ==="
    jq 'select(.responseStatus.code >= 400)' "$AUDIT_LOG" | \
        jq '{time: .requestReceivedTimestamp, user: .user.username, code: .responseStatus.code, verb: .verb, resource: .objectRef.resource}' | \
        tail -5
fi
```

### Step 4: Incident Response - Isolate compromised pod

```bash
# Apply network isolation
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-attacker
  namespace: lab-6-8
spec:
  podSelector:
    matchLabels:
      role: attacker
  policyTypes:
  - Ingress
  - Egress
EOF

echo "Pod isolated. No ingress or egress traffic allowed."

# Optionally, capture forensic evidence before deletion
kubectl exec -n lab-6-8 attacker-pod -- ps aux > /tmp/attacker-processes.txt 2>/dev/null || true
kubectl exec -n lab-6-8 attacker-pod -- netstat -an > /tmp/attacker-connections.txt 2>/dev/null || true

echo "Forensic data captured"
```

## Incident Response Checklist

1. **Detect**: Falco alert triggered
2. **Identify**: Determine affected pod/namespace
3. **Isolate**: Apply NetworkPolicy to block all traffic
4. **Investigate**: Collect forensic evidence (processes, connections, files)
5. **Eradicate**: Delete compromised pod
6. **Recover**: Deploy clean replacement
7. **Document**: Record timeline and actions taken

## CKS Exam Tips

- Know the MITRE ATT&CK framework for containers
- Understand common attack vectors: shell spawning, file access, network exfiltration
- Practice writing Falco rules for each attack type
- Know how to use `jq` to query audit logs
- Understand NetworkPolicy as an incident response tool
- Remember: detection → isolation → investigation → remediation
