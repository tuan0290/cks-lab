# Lab 6.7: Threat Detection - Attack Simulation and Response

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Hard
- **Estimated Time**: 35 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Simulate common Kubernetes attack scenarios
- Use Falco to detect runtime threats in real-time
- Analyze Kubernetes audit logs to identify suspicious activity
- Implement detection rules for container escape attempts
- Practice incident response procedures for Kubernetes security events
- Correlate multiple security signals to identify attack chains

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Falco installed and running
- jq installed for log analysis
- Basic understanding of Kubernetes attack vectors

## Scenario

Your cluster has been flagged for suspicious activity. You need to:
1. Set up Falco rules to detect common attack patterns
2. Simulate attack scenarios to validate detection
3. Analyze audit logs to identify the attack timeline
4. Implement response procedures to contain the threat

The attack scenarios include:
- **Scenario A**: Container shell spawning (potential backdoor)
- **Scenario B**: Sensitive file access from a container
- **Scenario C**: Unexpected network connection from a container
- **Scenario D**: Kubernetes API server reconnaissance

## Requirements

1. Create Falco rules to detect shell spawning in containers
2. Create Falco rules to detect unexpected outbound connections
3. Create Falco rules to detect Kubernetes API reconnaissance
4. Simulate each attack scenario and verify Falco generates alerts
5. Analyze audit logs to identify the attack timeline using jq
6. Document the incident response steps taken

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-6-7`.

2. **Task**: Create a ConfigMap named `threat-detection-rules` in namespace `falco` with Falco rules for:
   - **Shell spawning**: detect `proc.name in (shell_binaries)` inside containers
   - **API reconnaissance**: detect `proc.name in (kubectl, curl, wget)` accessing the Kubernetes API from containers
   - **Crypto mining**: detect processes with high CPU usage patterns (`proc.name in (xmrig, minerd, cryptonight)`)

3. **Task**: Create a Pod named `attack-simulator` in namespace `lab-6-7` using image `alpine:3.19` with command `["sleep", "3600"]`.

4. **Task**: Simulate attack scenarios:
   ```bash
   # Scenario A: Shell spawning
   kubectl exec attack-simulator -n lab-6-7 -- sh -c "id && whoami"
   
   # Scenario B: Sensitive file access
   kubectl exec attack-simulator -n lab-6-7 -- cat /etc/passwd
   ```

5. **Task**: Create a ConfigMap named `incident-response-plan` in namespace `lab-6-7` documenting:
   - How to isolate a compromised pod (NetworkPolicy or label change)
   - How to capture forensic evidence (`kubectl exec` logs, audit logs)
   - How to quarantine: `kubectl label pod <pod> quarantine=true`
   - Escalation procedure

6. **Task**: Create a ConfigMap named `attack-timeline` in namespace `lab-6-7` documenting the simulated attack timeline with timestamps.

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create comprehensive threat detection rules

Create `falco-threat-detection-rules.yaml`:

```yaml
# falco-threat-detection-rules.yaml

# Rule 1: Detect shell spawning in containers
- rule: Shell Spawned in Container
  desc: Detect shell process spawned inside a container
  condition: >
    spawned_process and
    container and
    shell_procs and
    not known_shell_spawners
  output: >
    Shell spawned in container (user=%user.name shell=%proc.name
    parent=%proc.pname cmdline=%proc.cmdline container=%container.name
    image=%container.image.repository pod=%k8s.pod.name
    namespace=%k8s.ns.name)
  priority: WARNING
  tags: [shell, container, cks]

- macro: shell_procs
  condition: proc.name in (bash, sh, zsh, ksh, fish, dash)

- macro: known_shell_spawners
  condition: >
    proc.pname in (containerd-shim, runc, docker-init) or
    container.image.repository in (docker.io/library/alpine,
                                    docker.io/library/ubuntu)

# Rule 2: Detect unexpected outbound connections
- rule: Unexpected Outbound Connection
  desc: Detect unexpected outbound network connection from container
  condition: >
    outbound and
    container and
    not fd.sport in (80, 443, 53, 8080, 8443) and
    not known_outbound_destinations
  output: >
    Unexpected outbound connection (user=%user.name command=%proc.cmdline
    connection=%fd.name container=%container.name
    image=%container.image.repository)
  priority: WARNING
  tags: [network, container, cks]

- macro: known_outbound_destinations
  condition: >
    fd.sip in (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)

# Rule 3: Detect Kubernetes API reconnaissance
- rule: K8s API Reconnaissance
  desc: Detect kubectl commands that enumerate cluster resources
  condition: >
    spawned_process and
    proc.name = "kubectl" and
    proc.args contains "get" and
    (proc.args contains "secrets" or
     proc.args contains "serviceaccounts" or
     proc.args contains "clusterrolebindings")
  output: >
    Kubernetes API reconnaissance detected (user=%user.name
    command=%proc.cmdline container=%container.name
    pod=%k8s.pod.name)
  priority: WARNING
  tags: [kubernetes, reconnaissance, cks]

# Rule 4: Detect container escape attempt via /proc
- rule: Container Escape via Proc
  desc: Detect attempt to access host /proc filesystem
  condition: >
    open_read and
    container and
    fd.name startswith /proc/1/ and
    not proc.name in (ps, top, htop)
  output: >
    Container escape attempt via /proc (user=%user.name
    command=%proc.cmdline file=%fd.name container=%container.name
    image=%container.image.repository)
  priority: CRITICAL
  tags: [container, escape, cks]
```

### Step 3: Deploy the threat detection rules

```bash
kubectl create configmap falco-threat-detection \
  --from-file=falco-threat-detection-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Falco to load rules
kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco
```

### Step 4: Simulate Attack Scenario A - Shell Spawning

```bash
# Get the attacker pod
ATTACKER=$(kubectl get pod -n lab-6-7 -l role=attacker -o jsonpath='{.items[0].metadata.name}')

# Simulate shell spawning (attacker gaining shell access)
kubectl exec -n lab-6-7 $ATTACKER -- /bin/sh -c "echo 'Shell spawned by attacker'"

# Check Falco logs for the alert
sleep 3
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i "shell spawned"
```

### Step 5: Simulate Attack Scenario B - Sensitive File Access

```bash
# Simulate reading sensitive files
kubectl exec -n lab-6-7 $ATTACKER -- cat /etc/shadow 2>/dev/null || true
kubectl exec -n lab-6-7 $ATTACKER -- cat /etc/passwd

# Check Falco logs
sleep 3
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i "sensitive\|shadow\|passwd"
```

### Step 6: Analyze audit logs for attack timeline

```bash
# If audit logging is enabled, analyze the logs
AUDIT_LOG="/var/log/kubernetes/audit.log"

# Find all actions by the attacker's service account
if [ -f "$AUDIT_LOG" ]; then
    echo "=== Recent kubectl exec events ==="
    grep '"verb":"create"' "$AUDIT_LOG" | \
        grep '"resource":"pods"' | \
        grep '"subresource":"exec"' | \
        jq '{time: .requestReceivedTimestamp, user: .user.username, pod: .objectRef.name, namespace: .objectRef.namespace}' | \
        tail -10

    echo "=== Failed authentication attempts ==="
    jq 'select(.responseStatus.code == 401 or .responseStatus.code == 403)' "$AUDIT_LOG" | \
        jq '{time: .requestReceivedTimestamp, user: .user.username, verb: .verb, resource: .objectRef.resource}' | \
        tail -10
else
    echo "Audit log not found at $AUDIT_LOG"
    echo "Check your cluster's audit log configuration"
fi
```

### Step 7: Incident Response - Isolate the compromised pod

```bash
# Apply a NetworkPolicy to isolate the attacker pod
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-attacker
  namespace: lab-6-7
spec:
  podSelector:
    matchLabels:
      role: attacker
  policyTypes:
  - Ingress
  - Egress
EOF

echo "Attacker pod isolated via NetworkPolicy"
```

### Step 8: Verify your solution

```bash
./verify.sh
```

## Verification

```bash
./verify.sh
```

## Cleanup

```bash
./cleanup.sh
```

## Additional Resources

- [Falco Rules Documentation](https://falco.org/docs/rules/)
- [Kubernetes Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
