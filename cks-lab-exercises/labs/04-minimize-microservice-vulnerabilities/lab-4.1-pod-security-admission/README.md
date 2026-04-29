# Lab 4.1: Pod Security Admission (PSA) — Thay thế PSP

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Medium
- **Estimated Time**: 13 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Pod Security Admission (PSA) — Thay thế PSP
- Apply security best practices

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```yaml
# Cấp độ 1: Privileged (không giới hạn) — KHÔNG dùng trong production

## Requirements

1. Create namespace `lab-4-1-baseline` with PSA `baseline` enforcement
2. Create namespace `lab-4-1-restricted` with PSA `restricted` enforcement
3. Verify a compliant pod runs in `restricted` namespace
4. Verify a privileged pod is blocked in `baseline` namespace

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create a namespace named `lab-4-1-baseline` with these labels:
   ```yaml
   pod-security.kubernetes.io/enforce: baseline
   pod-security.kubernetes.io/enforce-version: latest
   pod-security.kubernetes.io/warn: baseline
   pod-security.kubernetes.io/audit: baseline
   ```

2. **Task**: Create a namespace named `lab-4-1-restricted` with these labels:
   ```yaml
   pod-security.kubernetes.io/enforce: restricted
   pod-security.kubernetes.io/enforce-version: latest
   ```

3. **Task**: Attempt to create a privileged Pod in `lab-4-1-baseline` and confirm it is **blocked**:
   ```bash
   kubectl run priv-test --image=nginx:1.25 -n lab-4-1-baseline \
     --overrides='{"spec":{"containers":[{"name":"c","image":"nginx:1.25","securityContext":{"privileged":true}}]}}'
   # Expected: Error - violates PodSecurity "baseline"
   ```

4. **Task**: Create a fully compliant Pod named `restricted-pod` in `lab-4-1-restricted` with:
   - `securityContext.runAsNonRoot: true`, `runAsUser: 1000`
   - `securityContext.seccompProfile.type: RuntimeDefault`
   - `containers[0].securityContext.allowPrivilegeEscalation: false`
   - `containers[0].securityContext.capabilities.drop: [ALL]`
   - `containers[0].securityContext.readOnlyRootFilesystem: true`

5. **Verify**: Run `./verify.sh` — all checks must pass.

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
kind: Namespace

Create and apply the following Kubernetes resources:

```yaml
# Cấp độ 1: Privileged (không giới hạn) — KHÔNG dùng trong production

# Cấp độ 2: Baseline (giới hạn cơ bản)
apiVersion: v1
kind: Namespace
metadata:
  name: baseline-ns
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline

---
# Cấp độ 3: Restricted (giới hạn chặt nhất) — Dùng cho production
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

```yaml
# Ví dụ Pod đúng chuẩn Restricted level
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: production
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```
*- Volume types bị giới hạn (không có `hostPath`)*


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
