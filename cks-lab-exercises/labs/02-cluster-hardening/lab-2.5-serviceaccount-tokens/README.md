# Lab 2.5: ServiceAccount Token Management

## Metadata

- **Domain**: 2 - Cluster Hardening
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Disable automatic ServiceAccount token mounting for pods that don't need it
- Create bound ServiceAccount tokens with expiration using TokenRequest API
- Understand the difference between legacy tokens and bound tokens
- Restrict ServiceAccount permissions using RBAC

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

Several pods in your cluster are automatically mounting ServiceAccount tokens they don't need, creating unnecessary attack surface. You must disable auto-mounting for these pods and create a dedicated ServiceAccount with minimal permissions for pods that do need API access.

## Requirements

1. Create namespace `lab-2-5`
2. Create a ServiceAccount `no-token-sa` with `automountServiceAccountToken: false`
3. Create a Pod `no-token-pod` using `no-token-sa` that also sets `automountServiceAccountToken: false`
4. Create a ServiceAccount `api-reader-sa` with a Role allowing only `get` on pods
5. Create a Pod `api-reader-pod` using `api-reader-sa`

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-2-5`.

2. **Task**: Create a ServiceAccount named `no-token-sa` in namespace `lab-2-5` with `automountServiceAccountToken: false`.

3. **Task**: Create a Pod named `no-token-pod` in namespace `lab-2-5` that:
   - Uses ServiceAccount `no-token-sa`
   - Sets `automountServiceAccountToken: false` at the pod level
   - Confirm no token is mounted: `kubectl exec no-token-pod -n lab-2-5 -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1`

4. **Task**: Create a ServiceAccount named `api-reader-sa` in namespace `lab-2-5`, a Role named `pod-reader` allowing only `get` and `list` on `pods`, and a RoleBinding `api-reader-binding` connecting them.

5. **Task**: Create a Pod named `api-reader-pod` in namespace `lab-2-5` using ServiceAccount `api-reader-sa`.

6. **Task**: Generate a short-lived bound token for `api-reader-sa` with 1-hour expiry:
   ```bash
   kubectl create token api-reader-sa -n lab-2-5 --duration=3600s
   ```

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-token-sa
  namespace: lab-2-5
automountServiceAccountToken: false
EOF
```

### Step 3: Create pod that doesn't mount a token

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
  namespace: lab-2-5
spec:
  serviceAccountName: no-token-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: nginx:1.25
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF
```

### Step 4: Create a least-privilege ServiceAccount for API access

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-reader-sa
  namespace: lab-2-5
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: lab-2-5
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: api-reader-binding
  namespace: lab-2-5
subjects:
- kind: ServiceAccount
  name: api-reader-sa
  namespace: lab-2-5
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: Pod
metadata:
  name: api-reader-pod
  namespace: lab-2-5
spec:
  serviceAccountName: api-reader-sa
  containers:
  - name: app
    image: nginx:1.25
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF
```

### Step 5: Create a bound token with expiration

```bash
# Create a short-lived token (1 hour)
kubectl create token api-reader-sa -n lab-2-5 --duration=3600s
```

### Step 6: Verify your solution

```bash
./verify.sh
```

## Verification

```bash
./verify.sh
```

## Cleanup

```bash
./cleanup.sh
```

## Key Concepts

- **automountServiceAccountToken: false**: Prevents the default token from being mounted in the pod
- **Bound tokens**: Short-lived tokens tied to a specific pod/audience (TokenRequest API)
- **Legacy tokens**: Long-lived tokens stored as Secrets (deprecated in v1.24+)
- **Least privilege**: ServiceAccounts should only have the permissions they need

## Additional Resources

- [ServiceAccount Token Management](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/)
- [Bound Service Account Tokens](https://kubernetes.io/docs/concepts/security/service-accounts/#bound-service-account-tokens)
