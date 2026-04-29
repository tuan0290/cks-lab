# Solution: Lab 6.2 - Viết Falco Rules

## Overview

This solution provides step-by-step instructions for completing the Viết Falco Rules lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Apply Unknown

Create a file with the following content:

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

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 3: tags: [kubernetes, audit]

Create a file with the following content:

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

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 4: Verify the configuration

Run the verification script to confirm everything is working:

```bash
./verify.sh
```

## Verification

After completing all steps, verify your solution:

```bash
./verify.sh
```

Expected output: All checks should pass.

## Common Mistakes

- Forgetting to create the namespace before applying resources
- Not waiting for resources to be ready before verification
- Incorrect YAML indentation

## Troubleshooting

**Issue**: Resources not being created

**Solution**: Check kubectl logs and describe the resources to see error messages. Verify YAML syntax and API versions.

**Issue**: Verification script fails

**Solution**: Review the specific check that failed. Use kubectl get/describe commands to inspect the actual state of resources.

## Key Takeaways

- Understanding Viết Falco Rules is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
