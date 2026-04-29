# Lab 3.1: seccomp Profile

## Metadata

- **Domain**: 3 - System Hardening
- **Difficulty**: Medium
- **Estimated Time**: 13 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand seccomp Profile

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```json
// /var/lib/kubelet/seccomp/my-profile.json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "read", "write", "open", "close", "stat", "fstat",
        "lstat", "poll", "lseek", "mmap", "brk",
        "rt_sigaction", "rt_sigprocmask", "rt_sigreturn",
        "ioctl", "pread64", "pwrite64", "readv", "writev",
        "access", "pipe", "select", "sched_yield", "mremap",
        "munmap", "dup", "dup2", "pause",

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

```json
// /var/lib/kubelet/seccomp/my-profile.json
{

Create and apply the following Kubernetes resources:

```yaml
# Cách 1: Dùng Localhost profile tùy chỉnh
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: my-profile.json  # relative to /var/lib/kubelet/seccomp/
  containers:
  - name: container
    image: nginx:alpine
```
*}*

```yaml
# Cách 2 (Khuyến nghị): Dùng RuntimeDefault
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default-seccomp
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault   # Mặc định của container runtime
  containers:
  - name: container
    image: nginx:alpine
```
*image: nginx:alpine*


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
