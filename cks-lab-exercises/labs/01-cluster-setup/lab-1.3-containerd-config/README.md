# Lab 1.3: Cấu hình containerd

## Metadata

- **Domain**: 1 - Cluster Setup
- **Difficulty**: Easy
- **Estimated Time**: 9 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Cấu hình containerd

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```toml
# /etc/containerd/config.toml
version = 3
[plugins."io.containerd.grpc.v1.cri"]
  [plugins."io.containerd.grpc.v1.cri".containerd]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
          SystemdCgroup = true
```

## Requirements

1. Verify containerd is running on the node with `systemctl status containerd`
2. Inspect `/etc/containerd/config.toml` and confirm `SystemdCgroup = true` is set
3. Create a ConfigMap `containerd-config-summary` in namespace `lab-1-3` documenting the current containerd configuration
4. Create a ConfigMap `containerd-security-settings` documenting recommended security settings

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-1-3`.

2. **Task**: Inspect the containerd configuration on the node:
   ```bash
   cat /etc/containerd/config.toml
   ```
   Confirm that `SystemdCgroup = true` is set under the runc runtime options. If not, add it and restart containerd:
   ```bash
   systemctl restart containerd
   ```

3. **Task**: Create a ConfigMap named `containerd-config-summary` in namespace `lab-1-3` with the following data:
   - Key `runtime`: value `io.containerd.runc.v2`
   - Key `systemd-cgroup`: value `true`
   - Key `config-path`: value `/etc/containerd/config.toml`

4. **Task**: Create a ConfigMap named `containerd-security-settings` in namespace `lab-1-3` documenting at least 3 security settings:
   - `SystemdCgroup: true` — use systemd for cgroup management
   - `no_new_privileges: true` — prevent privilege escalation
   - `seccomp_profile: RuntimeDefault` — apply default seccomp profile

5. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```toml
version = 3
[plugins."io.containerd.grpc.v1.cri"]


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
