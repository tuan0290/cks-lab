# Lab 4.2: Trivy - Quét lỗ hổng image

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Medium
- **Estimated Time**: 18 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Trivy - Quét lỗ hổng image

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- trivy
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# Quét cơ bản
trivy image nginx:1.21

## Requirements

1. Execute the necessary commands to configure Trivy - Quét lỗ hổng image
2. Verify the configuration is working correctly

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```bash
trivy image nginx:1.21
trivy image --severity HIGH,CRITICAL nginx:1.21

Execute the following commands:

```bash
trivy image nginx:1.21
```

```bash
trivy image --severity HIGH,CRITICAL nginx:1.21
```

```bash
trivy image --format json nginx:1.21
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
