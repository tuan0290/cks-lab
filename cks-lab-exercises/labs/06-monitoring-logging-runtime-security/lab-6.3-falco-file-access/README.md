# Lab 6.3: Falco Custom Rules - Sensitive File Access Monitoring

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Write Falco rules to detect access to sensitive files like `/etc/shadow` and `/etc/passwd`
- Understand Falco rule syntax: condition, output, priority, and tags
- Deploy custom Falco rules via Kubernetes ConfigMap
- Test and validate Falco alert generation for file access events
- Analyze Falco logs to identify security incidents

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Falco installed (via Helm or DaemonSet)
- Basic understanding of Falco rule syntax

## Scenario

Your security team has identified that containers in the cluster may be attempting to read sensitive system files such as `/etc/shadow`, `/etc/passwd`, and `/etc/sudoers`. You need to create Falco custom rules to detect and alert on these file access events. The rules must be deployed as a Kubernetes ConfigMap and loaded by Falco without restarting the DaemonSet.

## Requirements

1. Create a Falco custom rule that detects read access to `/etc/shadow`, `/etc/passwd`, and `/etc/sudoers`
2. The rule must exclude legitimate system processes (sshd, login, systemd-logind)
3. Deploy the custom rules via a Kubernetes ConfigMap in the `falco` namespace
4. Verify that Falco generates alerts when a container accesses sensitive files
5. The rule output must include: user name, process command line, and file name

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-6-3`.

2. **Task**: Create a ConfigMap named `falco-file-access-rules` in namespace `falco` with a `rules.yaml` key containing:
   ```yaml
   - rule: Sensitive File Access in Container
     desc: Detect reads of sensitive files from containers
     condition: >
       open_read and container and
       fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers, /root/.ssh/authorized_keys) and
       not proc.name in (sshd, login, systemd-logind, passwd)
     output: >
       Sensitive file read in container
       (user=%user.name cmd=%proc.cmdline file=%fd.name
       pod=%k8s.pod.name ns=%k8s.ns.name)
     priority: ERROR
     tags: [filesystem, sensitive, container]
   ```

3. **Task**: Create a Pod named `file-access-test` in namespace `lab-6-3` using image `alpine:3.19` with command `["sleep", "3600"]`.

4. **Task**: Trigger the Falco rule by accessing a sensitive file from the test pod:
   ```bash
   kubectl exec file-access-test -n lab-6-3 -- cat /etc/passwd
   ```
   Then verify Falco logged the alert:
   ```bash
   kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep "Sensitive file"
   ```

5. **Task**: Create a ConfigMap named `file-access-test-results` in namespace `lab-6-3` documenting the alert output from Falco.

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This creates a test namespace and a pod that will be used to simulate file access.

### Step 2: Create the Falco custom rule for sensitive file access

Create a file `falco-file-access-rules.yaml` with the following content:

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

### Step 3: Deploy the rules as a ConfigMap

```bash
kubectl create configmap falco-file-access-rules \
  --from-file=falco-file-access-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 4: Update Falco to load the custom rules

If Falco is deployed via Helm, update the values to include the custom rules ConfigMap:

```bash
# Check if Falco is running
kubectl get pods -n falco

# Restart Falco to pick up new rules (or use hot-reload if supported)
kubectl rollout restart daemonset/falco -n falco

# Wait for rollout to complete
kubectl rollout status daemonset/falco -n falco
```

### Step 5: Test the rule by accessing sensitive files

```bash
# Get the test pod name
TEST_POD=$(kubectl get pod -n lab-6-3 -l app=file-access-test -o jsonpath='{.items[0].metadata.name}')

# Attempt to read /etc/shadow (this should trigger the Falco rule)
kubectl exec -n lab-6-3 $TEST_POD -- cat /etc/shadow 2>/dev/null || true

# Attempt to read /etc/passwd
kubectl exec -n lab-6-3 $TEST_POD -- cat /etc/passwd 2>/dev/null || true
```

### Step 6: Verify Falco alerts are generated

```bash
# Check Falco logs for alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50 | grep -i "sensitive file"

# Or check system journal if Falco runs as a service
# journalctl -u falco --since "5 minutes ago" | grep "Sensitive file"
```

### Step 7: Verify your solution

```bash
./verify.sh
```

## Verification

Run the verification script to check your solution:

```bash
./verify.sh
```

All checks should pass before proceeding.

## Cleanup

After completing the lab, clean up the resources:

```bash
./cleanup.sh
```

## Additional Resources

- [Falco Rules Documentation](https://falco.org/docs/rules/)
- [Falco Supported Fields](https://falco.org/docs/reference/rules/supported-fields/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
