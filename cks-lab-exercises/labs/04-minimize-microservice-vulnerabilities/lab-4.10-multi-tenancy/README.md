# Lab 4.10: Multi-Tenancy Isolation

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Implement namespace-based multi-tenancy isolation
- Configure ResourceQuota and LimitRange per tenant
- Apply NetworkPolicy for tenant isolation
- Use RBAC to restrict tenant access

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

You need to set up two isolated tenant namespaces (`tenant-a` and `tenant-b`) with resource limits, network isolation, and RBAC so each tenant can only access their own namespace.

## Requirements

1. Create namespaces `tenant-a` and `tenant-b` with PSS restricted labels
2. Create ResourceQuota in each namespace limiting CPU, memory, and pod count
3. Create NetworkPolicy in each namespace blocking cross-tenant traffic
4. Create ServiceAccounts `tenant-a-user` and `tenant-b-user` with namespace-scoped RBAC

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create two namespaces `tenant-a` and `tenant-b`, each with:
   - Label `tenant: <tenant-name>`
   - Pod Security Standard labels: `pod-security.kubernetes.io/enforce: restricted`

2. **Task**: Create a ResourceQuota named `tenant-quota` in **each** tenant namespace with:
   - `pods: "10"`
   - `requests.cpu: "2"`, `requests.memory: 2Gi`
   - `limits.cpu: "4"`, `limits.memory: 4Gi`

3. **Task**: Create a NetworkPolicy named `tenant-isolation` in **each** tenant namespace that:
   - Allows ingress **only** from the same tenant namespace
   - Allows egress **only** to the same tenant namespace
   - Allows egress to `kube-system` on UDP/TCP port 53 for DNS

4. **Task**: Create a ServiceAccount named `<tenant>-user` in each tenant namespace with a Role `tenant-role` allowing `get/list/create/update/delete` on `pods`, `deployments`, `services`, `configmaps`.

5. **Task**: Verify tenant-a cannot access tenant-b:
   ```bash
   kubectl auth can-i list pods -n tenant-b \
     --as=system:serviceaccount:tenant-a:tenant-a-user
   # Expected: no
   ```

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

```bash
for tenant in tenant-a tenant-b; do
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $tenant
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    tenant: $tenant
EOF
done
```

### Step 3: Create ResourceQuota per tenant

```bash
for tenant in tenant-a tenant-b; do
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: $tenant
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    secrets: "20"
    configmaps: "20"
EOF
done
```

### Step 4: Create NetworkPolicy for tenant isolation

```bash
for tenant in tenant-a tenant-b; do
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: $tenant
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant: $tenant
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: $tenant
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
done
```

### Step 5: Create tenant ServiceAccounts with RBAC

```bash
for tenant in tenant-a tenant-b; do
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${tenant}-user
  namespace: $tenant
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tenant-role
  namespace: $tenant
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "deployments", "services", "configmaps"]
  verbs: ["get", "list", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-binding
  namespace: $tenant
subjects:
- kind: ServiceAccount
  name: ${tenant}-user
  namespace: $tenant
roleRef:
  kind: Role
  name: tenant-role
  apiGroup: rbac.authorization.k8s.io
EOF
done
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

- **Namespace isolation**: Primary boundary for multi-tenancy in Kubernetes
- **ResourceQuota**: Limits total resource consumption per namespace
- **NetworkPolicy**: Prevents cross-tenant network communication
- **RBAC**: Restricts API access to own namespace only

## Additional Resources

- [Multi-tenancy](https://kubernetes.io/docs/concepts/security/multi-tenancy/)
- [ResourceQuota](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
