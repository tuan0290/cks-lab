# Lab 2.2: RBAC - Nguyên tắc Tối Thiểu Đặc Quyền

## Metadata

- **Domain**: 2 - Cluster Hardening
- **Difficulty**: Easy
- **Estimated Time**: 13 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand RBAC - Nguyên tắc Tối Thiểu Đặc Quyền

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

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
apiVersion: rbac.authorization.k8s.i

## Requirements

1. Create namespace `lab-2-2` with label `security=rbac`
2. Create a ServiceAccount `deployment-reader` in namespace `lab-2-2`
3. Create a Role `deployment-reader-role` allowing only `get` and `list` on `deployments` and `pods`
4. Bind the Role to the ServiceAccount via a RoleBinding
5. Verify permissions using `kubectl auth can-i`

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-2-2` with label `security=rbac`.

2. **Task**: Create a ServiceAccount named `deployment-reader` in namespace `lab-2-2` with `automountServiceAccountToken: false`.

3. **Task**: Create a Role named `deployment-reader-role` in namespace `lab-2-2` that allows:
   - `get`, `list` on `deployments` (apiGroup: `apps`)
   - `get`, `list` on `pods` (apiGroup: `""`)
   - **No** `create`, `update`, `delete`, or `patch` verbs

4. **Task**: Create a RoleBinding named `deployment-reader-binding` in namespace `lab-2-2` that binds `deployment-reader-role` to ServiceAccount `deployment-reader`.

5. **Task**: Verify the permissions are correct:
   ```bash
   # Should return "yes"
   kubectl auth can-i list deployments -n lab-2-2 \
     --as=system:serviceaccount:lab-2-2:deployment-reader
   
   # Should return "no"
   kubectl auth can-i delete deployments -n lab-2-2 \
     --as=system:serviceaccount:lab-2-2:deployment-reader
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

```yaml
apiVersion: v1
kind: ServiceAccount

Execute the following commands:

```bash
kubectl auth can-i delete secrets -n default --as=system:anonymous
```
*automountServiceAccountToken: true  # hoặc false nếu không cần*

```bash
kubectl auth can-i get secrets --all-namespaces
```
*automountServiceAccountToken: true  # hoặc false nếu không cần*

Create and apply the following Kubernetes resources:

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
