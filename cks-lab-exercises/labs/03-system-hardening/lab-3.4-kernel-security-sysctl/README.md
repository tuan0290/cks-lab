# Lab 3.4: Kernel Security Parameters (sysctl)

## Metadata

- **Domain**: 3 - System Hardening
- **Difficulty**: Hard
- **Estimated Time**: 22 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Kernel Security Parameters (sysctl)
- Apply security best practices

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# /etc/sysctl.d/99-kubernetes-security.conf

## Requirements

1. Execute the necessary commands to configure Kernel Security Parameters (sysctl)
2. Verify the configuration is working correctly
3. Document any troubleshooting steps you performed

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```bash
net.ipv4.ip_forward=0
net.ipv4.conf.all.send_redirects=0

Execute the following commands:

```bash
net.ipv4.ip_forward=0
```

```bash
net.ipv4.conf.all.send_redirects=0
```

```bash
net.ipv4.conf.default.send_redirects=0
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
