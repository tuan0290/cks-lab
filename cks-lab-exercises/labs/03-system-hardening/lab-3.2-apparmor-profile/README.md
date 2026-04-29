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

1. Execute the necessary commands to configure AppArmor Configuration
2. Create and apply the required Kubernetes manifests
3. Verify the configuration is working correctly
4. Document any troubleshooting steps you performed

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
