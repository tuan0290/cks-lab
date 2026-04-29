# Lab 3.3: Linux Capabilities Management

## Metadata

- **Domain**: 3 - System Hardening
- **Difficulty**: Easy
- **Estimated Time**: 11 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Linux Capabilities Management

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL                    # Drop tất cả capabilities
        add:
        - NET_BIND_SERVICE       # Chỉ thêm capability cần thiết (bind port <1024)
      pri

## Requirements

1. Create namespace `lab-3-3`
2. Create a Pod `drop-all-pod` that drops ALL capabilities and adds only `NET_BIND_SERVICE`
3. Create a Pod `privileged-pod` with `privileged: true` to demonstrate the risk
4. Verify capabilities using `kubectl exec`

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-3-3`.

2. **Task**: Create a Pod named `drop-all-pod` in namespace `lab-3-3` using image `nginx:1.25` with:
   - `securityContext.runAsNonRoot: true`
   - `securityContext.runAsUser: 1000`
   - `containers[0].securityContext.allowPrivilegeEscalation: false`
   - `containers[0].securityContext.capabilities.drop: [ALL]`
   - `containers[0].securityContext.capabilities.add: [NET_BIND_SERVICE]`

3. **Task**: Create a Pod named `no-caps-pod` in namespace `lab-3-3` using image `busybox:1.36` with:
   - `containers[0].securityContext.capabilities.drop: [ALL]`
   - `containers[0].securityContext.allowPrivilegeEscalation: false`
   - Command: `["sleep", "3600"]`

4. **Task**: Verify the capabilities on `drop-all-pod`:
   ```bash
   kubectl exec drop-all-pod -n lab-3-3 -- cat /proc/1/status | grep Cap
   # CapEff should show only NET_BIND_SERVICE bit set
   ```

5. **Task**: Create a ConfigMap named `capabilities-reference` in namespace `lab-3-3` listing at least 5 dangerous capabilities that should always be dropped (e.g., `CAP_SYS_ADMIN`, `CAP_NET_ADMIN`, `CAP_SYS_PTRACE`, `CAP_DAC_OVERRIDE`, `CAP_SETUID`).

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```yaml
apiVersion: v1
kind: Pod

Create and apply the following Kubernetes resources:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL                    # Drop tất cả capabilities
        add:
        - NET_BIND_SERVICE       # Chỉ thêm capability cần thiết (bind port <1024)
      privileged: false
```


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
