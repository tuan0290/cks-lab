# Solution: Lab 2.2 - RBAC - Nguyên tắc Tối Thiểu Đặc Quyền

## Overview

This solution provides step-by-step instructions for completing the RBAC - Nguyên tắc Tối Thiểu Đặc Quyền lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: automountServiceAccountToken: true  # hoặc false nếu không cần

```bash
kubectl auth can-i delete secrets -n default --as=system:anonymous
```

automountServiceAccountToken: true  # hoặc false nếu không cần

### Step 3: automountServiceAccountToken: true  # hoặc false nếu không cần

```bash
kubectl auth can-i get secrets --all-namespaces
```

automountServiceAccountToken: true  # hoặc false nếu không cần

### Step 4: Apply Unknown

Create a file with the following content:

```yaml
# Tạo ServiceAccount với quyền tối thiểu (chỉ đọc deployment)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployment-reader
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-reader-role
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-reader-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: deployment-reader
  namespace: production
roleRef:
  kind: Role
  name: deployment-reader-role
  apiGroup: rbac.authorization.k8s.io
---
# Pod sử dụng SA với quyền tối thiểu
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: production
spec:
  serviceAccountName: deployment-reader
  automountServiceAccountToken: true  # hoặc false nếu không cần
```

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 5: Verify the configuration

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

- Understanding RBAC - Nguyên tắc Tối Thiểu Đặc Quyền is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
