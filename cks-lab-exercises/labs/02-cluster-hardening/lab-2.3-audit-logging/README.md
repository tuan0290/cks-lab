# Lab 2.3: Cấu hình Audit Log

## Metadata

- **Domain**: 2 - Cluster Hardening
- **Difficulty**: Medium
- **Estimated Time**: 16 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Cấu hình Audit Log

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - RequestReceived
rules:
  # Ghi log đầy đủ khi tạo/sửa/xóa Secret
  - level: RequestResponse
    verbs: ["create", "update", "delete", "patch"]
    resources:
    - group: ""
      resources: ["secrets"]

## Requirements

1. Execute the necessary commands to configure Cấu hình Audit Log
2. Create and apply the required Kubernetes manifests
3. Verify the configuration is working correctly

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy

Execute the following commands:

```bash
--audit-log-path=/var/log/kubernetes/audit.log
```
*resources: ["*"]*

```bash
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
```
*resources: ["*"]*

```bash
--audit-log-maxage=30
```
*resources: ["*"]*

Create and apply the following Kubernetes resources:

```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - RequestReceived
rules:
  # Ghi log đầy đủ khi tạo/sửa/xóa Secret
  - level: RequestResponse
    verbs: ["create", "update", "delete", "patch"]
    resources:
    - group: ""
      resources: ["secrets"]

  # Ghi metadata khi đọc Secret
  - level: Request
    verbs: ["get", "list"]
    resources:
    - group: ""
      resources: ["secrets"]

  # Ghi log đầy đủ cho Deployment/StatefulSet
  - level: RequestResponse
    verbs: ["create", "update", "delete", "patch"]
    resources:
    - group: "apps"
      resources: ["deployments", "statefulsets", "daemonsets"]
    - group: "batch"
      resources: ["jobs", "cronjobs"]

  # Metadata cho tất cả resource còn lại
  - level: Metadata
    verbs: ["*"]
    resources:
    - group: ""
      resources: ["*"]
    omitStages:
    - RequestReceived

  # Không ghi log node get/list events (giảm noise)
  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get", "list"]
    resources:
    - group: ""
      resources: ["events", "nodes"]

  # Ghi log anonymous requests
  - level: Request
    userGroups: ["system:unauthenticated"]
    resources:
    - group: ""
      resources: ["*"]
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
