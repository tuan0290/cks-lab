# Solution: Lab 2.3 - Cấu hình Audit Log

## Overview

This solution provides step-by-step instructions for completing the Cấu hình Audit Log lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: resources: ["*"]

```bash
--audit-log-path=/var/log/kubernetes/audit.log
```

resources: ["*"]

### Step 3: resources: ["*"]

```bash
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
```

resources: ["*"]

### Step 4: resources: ["*"]

```bash
--audit-log-maxage=30
```

resources: ["*"]

### Step 5: resources: ["*"]

```bash
--audit-log-maxbackup=10
```

resources: ["*"]

### Step 6: resources: ["*"]

```bash
--audit-log-maxsize=100
```

resources: ["*"]

### Step 7: Apply Policy

Create a file with the following content:

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

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 8: Verify the configuration

Run the verification script to confirm everything is working:

```bash
./verify.sh
```

## Verification

After completing all steps, verify your solution:

```bash
./verify.sh
```

Expected output: All checks should pass.

## Common Mistakes

- Forgetting to create the namespace before applying resources
- Not waiting for resources to be ready before verification
- Incorrect YAML indentation

## Troubleshooting

**Issue**: Resources not being created

**Solution**: Check kubectl logs and describe the resources to see error messages. Verify YAML syntax and API versions.

**Issue**: Verification script fails

**Solution**: Review the specific check that failed. Use kubectl get/describe commands to inspect the actual state of resources.

## Key Takeaways

- Understanding Cấu hình Audit Log is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
