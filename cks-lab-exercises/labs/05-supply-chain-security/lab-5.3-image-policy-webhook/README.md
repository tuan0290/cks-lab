# Lab 5.3: ImagePolicyWebhook

## Metadata

- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Easy
- **Estimated Time**: 11 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand ImagePolicyWebhook
- Create and enforce policies

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# Thêm vào kube-apiserver
--enable-admission-plugins=...,ImagePolicyWebhook
--admission-control-config-file=/etc/kubernetes/image-policy/admission_config.yaml
```

## Requirements

1. Execute the necessary commands to configure ImagePolicyWebhook
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
--enable-admission-plugins=...,ImagePolicyWebhook
--admission-control-config-file=/etc/kubernetes/image-policy/admission_config.yaml

Execute the following commands:

```bash
--enable-admission-plugins=...,ImagePolicyWebhook
```

```bash
--admission-control-config-file=/etc/kubernetes/image-policy/admission_config.yaml
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
