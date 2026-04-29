# Lab 6.3: Audit Log Query & Analysis

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Hard
- **Estimated Time**: 22 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Audit Log Query & Analysis

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# Tìm các thao tác với Secret
grep '"resource":"secrets"' /var/log/kubernetes/audit.log | \
  jq 'select(.stage=="ResponseComplete") | {user, verb, resource, statusCode}'

## Requirements

1. Execute the necessary commands to configure Audit Log Query & Analysis
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
grep '"resource":"secrets"' /var/log/kubernetes/audit.log | \
  jq 'select(.stage=="ResponseComplete") | {user, verb, resource, statusCode}'

Execute the following commands:

```bash
grep '"resource":"secrets"' /var/log/kubernetes/audit.log | \
```

```bash
jq 'select(.stage=="ResponseComplete") | {user, verb, resource, statusCode}'
```

```bash
jq 'select(.responseStatus.code==401)' /var/log/kubernetes/audit.log
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
