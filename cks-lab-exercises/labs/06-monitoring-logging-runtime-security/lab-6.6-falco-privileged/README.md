# Lab 6.6: Falco Custom Rules - Privileged Container Detection

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Write Falco rules to detect privileged container startup
- Detect privilege escalation attempts within containers
- Monitor containers running with dangerous Linux capabilities
- Deploy and test Falco rules for container privilege monitoring
- Understand the difference between privileged containers and capability escalation

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Falco installed (via Helm or DaemonSet)
- Basic understanding of Linux capabilities and container security

## Scenario

Your security team needs to detect when containers are started with privileged mode or dangerous capabilities. Attackers often use privileged containers to escape container isolation and gain access to the host system. You must create Falco rules to detect these scenarios and alert the security team immediately.

## Requirements

1. Create a Falco rule that detects privileged container startup (`container.privileged=true`)
2. Create a Falco rule that detects containers with dangerous capabilities (SYS_ADMIN, NET_ADMIN, SYS_PTRACE)
3. Exclude known legitimate privileged containers (e.g., Falco itself, CNI plugins)
4. Deploy the rules via a Kubernetes ConfigMap in the `falco` namespace
5. Test the rules by deploying a privileged pod and verifying Falco generates alerts
6. Rule output must include: container name, image, user, and privilege details

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-6-6`.

2. **Task**: Create a ConfigMap named `falco-privileged-rules` in namespace `falco` with a `rules.yaml` key containing:

   **Rule 1 — Privileged container**:
   ```yaml
   - rule: Privileged Container Started
     desc: Detect a privileged container being started
     condition: >
       container_started and container.privileged=true and
       not container.image.repository in (falco, cilium, calico)
     output: >
       Privileged container started
       (user=%user.name image=%container.image.repository:%container.image.tag
       pod=%k8s.pod.name ns=%k8s.ns.name)
     priority: CRITICAL
     tags: [container, privilege-escalation]
   ```

   **Rule 2 — Dangerous capabilities**:
   ```yaml
   - rule: Container with Dangerous Capabilities
     desc: Detect containers with SYS_ADMIN or NET_ADMIN capabilities
     condition: >
       container_started and
       (container.caps.effective contains SYS_ADMIN or
        container.caps.effective contains NET_ADMIN)
     output: >
       Container with dangerous capabilities
       (caps=%container.caps.effective pod=%k8s.pod.name ns=%k8s.ns.name)
     priority: WARNING
     tags: [container, capabilities]
   ```

3. **Task**: Create a privileged Pod named `privileged-test` in namespace `lab-6-6` to trigger the rule:
   ```yaml
   securityContext:
     privileged: true
   ```

4. **Task**: Verify Falco generated the alert:
   ```bash
   kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=30 | grep "Privileged container"
   ```

5. **Task**: Create a ConfigMap named `privileged-detection-results` in namespace `lab-6-6` documenting the Falco alert output.

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

This creates test pods including a privileged container to trigger the Falco rules.

### Step 2: Create Falco rules for privileged container detection

Create `falco-privileged-rules.yaml`:

```yaml
# falco-privileged-rules.yaml

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

# Macro for known legitimate privileged containers
- macro: known_privileged_containers
  condition: >
    container.image.repository in (
      falcosecurity/falco,
      falco-no-driver,
      kindest/node,
      calico/node,
      cilium/cilium,
      weave-npc
    )

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

### Step 3: Deploy the rules as a ConfigMap

```bash
kubectl create configmap falco-privileged-rules \
  --from-file=falco-privileged-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 4: Restart Falco to load the new rules

```bash
kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco
```

### Step 5: Test the privileged container rule

```bash
# Check the privileged test pod (created by setup.sh)
kubectl get pod privileged-test -n lab-6-6 -o jsonpath='{.spec.containers[0].securityContext}'

# Check Falco logs for the alert
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50 | grep -i "privileged"
```

### Step 6: Test with a new privileged pod

```bash
# Create a privileged pod to trigger the rule
kubectl run priv-test-2 \
  --image=busybox:1.35 \
  --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"priv-test-2","image":"busybox:1.35","command":["sleep","60"],"securityContext":{"privileged":true}}]}}' \
  -n lab-6-6

# Wait and check Falco logs
sleep 5
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i "privileged"

# Clean up
kubectl delete pod priv-test-2 -n lab-6-6 --ignore-not-found=true
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

## Cleanup

```bash
./cleanup.sh
```

## Additional Resources

- [Falco Rules Documentation](https://falco.org/docs/rules/)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Kubernetes Security Contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
