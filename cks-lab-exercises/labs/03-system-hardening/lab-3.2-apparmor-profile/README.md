# Lab 3.2: AppArmor Configuration

## Metadata

- **Domain**: 3 - System Hardening
- **Difficulty**: Hard
- **Estimated Time**: 26 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand AppArmor Configuration
- Configure AppArmor Configuration correctly

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# Tạo AppArmor profile tại /etc/apparmor.d/nginx-apparmor
#include <tunables/global>

## Requirements

1. Create namespace `lab-3-2`
2. Create an AppArmor profile `k8s-nginx-apparmor` and load it on the node
3. Create a Pod `apparmor-pod` with the AppArmor profile applied via annotation
4. Verify the profile is enforced

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-3-2`.

2. **Task**: Create an AppArmor profile file at `/etc/apparmor.d/k8s-nginx-apparmor` on the node:
   ```
   profile k8s-nginx-apparmor flags=(attach_disconnected) {
     #include <abstractions/base>
     file,
     network,
     deny /etc/shadow r,
     deny /proc/sys/kernel/** w,
   }
   ```
   Load the profile: `apparmor_parser -r /etc/apparmor.d/k8s-nginx-apparmor`

3. **Task**: Verify the profile is loaded:
   ```bash
   aa-status | grep k8s-nginx-apparmor
   ```

4. **Task**: Create a Pod named `apparmor-pod` in namespace `lab-3-2` using image `nginx:1.25` with the AppArmor annotation:
   ```yaml
   metadata:
     annotations:
       container.apparmor.security.beta.kubernetes.io/nginx: localhost/k8s-nginx-apparmor
   ```

5. **Task**: Verify the AppArmor profile is active on the running pod:
   ```bash
   kubectl exec apparmor-pod -n lab-3-2 -- cat /proc/1/attr/current
   # Expected: k8s-nginx-apparmor (enforce)
   ```

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```bash
profile nginx-apparmor flags=(attach_disconnected) {
  #include <abstractions/base>

Execute the following commands:

```bash
profile nginx-apparmor flags=(attach_disconnected) {
```

```bash
network inet stream,
```

```bash
network inet6 stream,
```

Create and apply the following Kubernetes resources:

```yaml
# Áp dụng AppArmor vào Pod
apiVersion: v1
kind: Pod
metadata:
  name: nginx-apparmor
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: nginx-apparmor
```
*sudo aa-status | grep nginx*


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
