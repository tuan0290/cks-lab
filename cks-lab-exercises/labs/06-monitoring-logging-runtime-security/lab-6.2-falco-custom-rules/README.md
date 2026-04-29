# Lab 6.2: Viết Falco Rules

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Medium
- **Estimated Time**: 15 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Viết Falco Rules

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- falco
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```yaml
# falco-custom-rules.yaml

## Requirements

1. Create and apply the required Kubernetes manifests
2. Verify the configuration is working correctly

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```yaml
- rule: Detect Shell Container
  desc: Detect creation of a shell container (potential backdoor)

Create and apply the following Kubernetes resources:

```yaml
# falco-custom-rules.yaml

# Rule 1: Phát hiện shell container (backdoor)
- rule: Detect Shell Container
  desc: Detect creation of a shell container (potential backdoor)
  condition: >
    shell_containers and not known_shell_containers
  output: >
    Shell container created (user=%user.name container=%container.name
    shell=%container.shell image=%container.image)
  priority: WARNING
  tags: [container, shell]

- macro: shell_containers
  condition: >
    container.entrypoint in (/bin/sh, /bin/bash, /bin/zsh, /bin/fish)

- macro: known_shell_containers
  condition: >
    container.image.repository in (docker.io/library/alpine,
    docker.io/library/ubuntu)

---
# Rule 2: Phát hiện truy cập file nhạy cảm
- rule: Detect Sensitive File Access
  desc: Detect access to sensitive files like /etc/shadow
  condition: >
    open_read and fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers)
    and not proc.aname in (sshd, login, systemd-logind)
  output: >
    Sensitive file access (user=%user.name command=%proc.cmdline file=%fd.name)
  priority: WARNING
  tags: [filesystem, security]

---
# Rule 3: Phát hiện Privileged Container
- rule: Detect Privileged Container
  desc: Detect privileged container startup
  condition: >
    container.privileged=true and not known_privileged_containers
  output: >
    Privileged container started (user=%user.name container=%container.name
    image=%container.image)
  priority: WARNING
  tags: [container, privilege]

---
# Rule 4: Phát hiện kubectl exec đáng ngờ
- rule: Suspicious kubectl exec
  desc: Multiple kubectl exec to different pods in short time
  condition: >
    spawned_process and proc.name="kubectl"
    and proc.args contains "exec"
    and proc.args contains "-it"
  output: >
    Suspicious kubectl exec detected (user=%user.name pod=%k8s.pod.name
    namespace=%k8s.pod.namespace command=%proc.cmdline)
  priority: WARNING
  tags: [kubernetes, exec]

---
# Rule 5: Phát hiện sửa đổi K8s Secret/ConfigMap
- rule: Detect Kubernetes Secret Modification
  desc: Detect modification to K8s secrets
  condition: >
    kubectl.modify and kubectl.resource in (secret, configmap)
  output: >
    Kubernetes secret/configmap modified (user=%user.name
    command=%kubectl.command resource=%kubectl.resource)
  priority: WARNING
  tags: [kubernetes, audit]
```

```yaml
# Deploy custom Falco rules bằng ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-custom-rules
  namespace: falco
data:
  custom-rules.yaml: |
    # Paste nội dung rules ở trên vào đây
```
*tags: [kubernetes, audit]*


### Step 3: Verify your solution

Use the verification script to check if your configuration is correct:

```bash
./verify.sh
```

Review any failed checks and make corrections as needed.

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

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
