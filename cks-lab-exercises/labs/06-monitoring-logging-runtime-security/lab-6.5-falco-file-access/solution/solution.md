# Solution: Lab 6.5 - Falco Custom Rules - Sensitive File Access Monitoring

## Overview

This solution demonstrates how to create Falco custom rules to detect access to sensitive system files and deploy them via Kubernetes ConfigMap.

## Step-by-Step Solution

### Step 1: Create the Falco custom rules file

Create `falco-file-access-rules.yaml`:

```yaml
# falco-file-access-rules.yaml
- rule: Detect Sensitive File Access
  desc: Detect read access to sensitive system files like /etc/shadow
  condition: >
    open_read and
    fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers, /etc/sudoers.d,
                /root/.ssh/authorized_keys, /root/.ssh/id_rsa,
                /etc/kubernetes/admin.conf) and
    not proc.name in (sshd, login, systemd-logind, passwd, chage, shadow,
                      useradd, usermod, groupadd, groupmod)
  output: >
    Sensitive file accessed (user=%user.name command=%proc.cmdline
    file=%fd.name container=%container.name image=%container.image.repository)
  priority: WARNING
  tags: [filesystem, security, cks]

- rule: Detect /etc/shadow Write Attempt
  desc: Detect any write attempt to /etc/shadow
  condition: >
    open_write and fd.name = /etc/shadow
  output: >
    Write attempt to /etc/shadow (user=%user.name command=%proc.cmdline
    container=%container.name image=%container.image.repository)
  priority: CRITICAL
  tags: [filesystem, security, cks]
```

### Step 2: Deploy the rules as a Kubernetes ConfigMap

```bash
kubectl create configmap falco-file-access-rules \
  --from-file=falco-file-access-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -
```

Verify the ConfigMap was created:

```bash
kubectl get configmap falco-file-access-rules -n falco
kubectl describe configmap falco-file-access-rules -n falco
```

### Step 3: Configure Falco to use the custom rules

**Option A: Helm-based Falco installation**

```bash
# Update Falco Helm values to mount the ConfigMap
helm upgrade falco falcosecurity/falco \
  --namespace falco \
  --set "falco.rules_file[0]=/etc/falco/falco_rules.yaml" \
  --set "falco.rules_file[1]=/etc/falco/falco_rules.local.yaml" \
  --set "falco.rules_file[2]=/etc/falco/custom-rules/falco-file-access-rules.yaml" \
  --set "extraVolumes[0].name=custom-rules" \
  --set "extraVolumes[0].configMap.name=falco-file-access-rules" \
  --set "extraVolumeMounts[0].name=custom-rules" \
  --set "extraVolumeMounts[0].mountPath=/etc/falco/custom-rules"
```

**Option B: Restart DaemonSet to pick up ConfigMap changes**

```bash
kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco
```

### Step 4: Test the rule

```bash
# Get the test pod name
TEST_POD=$(kubectl get pod -n lab-6-5 -l app=file-access-test -o jsonpath='{.items[0].metadata.name}')

# Trigger the rule by reading /etc/shadow
kubectl exec -n lab-6-5 $TEST_POD -- cat /etc/shadow 2>/dev/null || true

# Trigger the rule by reading /etc/passwd
kubectl exec -n lab-6-5 $TEST_POD -- cat /etc/passwd

# Trigger the rule by reading /etc/sudoers
kubectl exec -n lab-6-5 $TEST_POD -- cat /etc/sudoers 2>/dev/null || true
```

### Step 5: Verify Falco alerts

```bash
# Check Falco pod logs for alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=100 | grep -i "sensitive file\|shadow"

# Expected output:
# {"output":"Sensitive file accessed (user=root command=cat /etc/shadow file=/etc/shadow container=test-container image=busybox)","priority":"WARNING","rule":"Detect Sensitive File Access",...}
```

## Key Concepts

### Falco Rule Structure

```yaml
- rule: <rule_name>
  desc: <description>
  condition: <boolean_expression>
  output: <output_string_with_fields>
  priority: <EMERGENCY|ALERT|CRITICAL|ERROR|WARNING|NOTICE|INFORMATIONAL|DEBUG>
  tags: [<tag1>, <tag2>]
```

### Important Falco Fields for File Access

| Field | Description |
|-------|-------------|
| `fd.name` | File descriptor name (file path) |
| `open_read` | Macro: file opened for reading |
| `open_write` | Macro: file opened for writing |
| `proc.name` | Process name |
| `proc.cmdline` | Full process command line |
| `user.name` | User name |
| `container.name` | Container name |
| `container.image.repository` | Container image repository |

### Exclusion Patterns

Always exclude legitimate system processes to reduce false positives:

```yaml
not proc.name in (sshd, login, systemd-logind, passwd, chage, shadow,
                  useradd, usermod, groupadd, groupmod)
```

## Common Mistakes

1. **Missing exclusions**: Not excluding legitimate processes causes false positives
2. **Wrong priority**: Use WARNING or higher for security-relevant events
3. **Missing output fields**: Always include user, command, and file in output
4. **ConfigMap namespace**: Deploy the ConfigMap in the `falco` namespace, not `default`
5. **Not restarting Falco**: New rules require Falco restart or hot-reload to take effect

## Troubleshooting

```bash
# Check if Falco is running
kubectl get pods -n falco

# Check Falco logs for rule loading errors
kubectl logs -n falco -l app.kubernetes.io/name=falco | grep -i "error\|warn\|rule"

# Validate rule syntax (if falco binary available)
falco --validate /path/to/falco-file-access-rules.yaml

# Check ConfigMap content
kubectl get configmap falco-file-access-rules -n falco -o yaml
```

## CKS Exam Tips

- Falco rules are commonly tested in the CKS exam
- Know the key fields: `fd.name`, `proc.name`, `user.name`, `container.name`
- Remember to use `open_read` macro for read detection
- Always include meaningful output fields for incident response
- Deploy rules via ConfigMap for Kubernetes-native management
