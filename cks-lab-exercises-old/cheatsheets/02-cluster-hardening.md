# Cheatsheet 02 – Cluster Hardening (15%)

## RBAC

### Check permissions
```bash
# Can current user do X?
kubectl auth can-i get pods
kubectl auth can-i delete secrets -n kube-system
kubectl auth can-i create deployments --all-namespaces

# Impersonate a ServiceAccount
kubectl auth can-i list pods \
  --as=system:serviceaccount:<namespace>:<sa-name> \
  -n <namespace>

# List ALL permissions for current user
kubectl auth can-i --list
kubectl auth can-i --list -n <namespace>

# List permissions for a ServiceAccount
kubectl auth can-i --list \
  --as=system:serviceaccount:<namespace>:<sa-name> \
  -n <namespace>
```

### Create Role (namespace-scoped)
```bash
kubectl create role <name> \
  --verb=get,list,watch \
  --resource=pods \
  -n <namespace>

# With resource names
kubectl create role <name> \
  --verb=get,update \
  --resource=configmaps \
  --resource-name=my-config \
  -n <namespace>
```

### Create RoleBinding
```bash
# Bind user
kubectl create rolebinding <name> \
  --role=<role-name> \
  --user=<username> \
  -n <namespace>

# Bind ServiceAccount
kubectl create rolebinding <name> \
  --role=<role-name> \
  --serviceaccount=<namespace>:<sa-name> \
  -n <namespace>
```

### Create ClusterRole
```bash
kubectl create clusterrole <name> \
  --verb=get,list,watch \
  --resource=nodes,persistentvolumes
```

### Create ClusterRoleBinding
```bash
kubectl create clusterrolebinding <name> \
  --clusterrole=<clusterrole-name> \
  --serviceaccount=<namespace>:<sa-name>
```

### RBAC YAML templates

#### Role
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
```

#### RoleBinding
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: my-sa
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

#### ClusterRole
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
```

#### ClusterRoleBinding
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-reader-binding
subjects:
- kind: ServiceAccount
  name: my-sa
  namespace: default
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

### Find overly permissive bindings
```bash
# Find all ClusterRoleBindings
kubectl get clusterrolebinding -o wide

# Find bindings to cluster-admin
kubectl get clusterrolebinding -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'

# Find bindings with wildcard verbs
kubectl get clusterrole -o json | \
  jq '.items[] | select(.rules[]?.verbs[]? == "*") | .metadata.name'
```

---

## Audit Policy

### Audit levels
| Level | Description |
|-------|-------------|
| `None` | Don't log |
| `Metadata` | Log request metadata only (user, timestamp, resource) |
| `Request` | Log metadata + request body |
| `RequestResponse` | Log metadata + request + response body |

### Audit Policy YAML template
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log Secret access at RequestResponse level
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]

# Log pod exec/attach at RequestResponse
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods/exec", "pods/attach", "pods/portforward"]

# Log all other resources at Metadata level
- level: Metadata
  resources:
  - group: ""
    resources: ["pods", "services", "configmaps"]
  - group: "apps"
    resources: ["deployments", "replicasets"]

# Don't log read-only requests to non-sensitive resources
- level: None
  verbs: ["get", "list", "watch"]
  resources:
  - group: ""
    resources: ["endpoints", "services"]

# Default: log everything else at Metadata
- level: Metadata
```

### Configure kube-apiserver for audit logging
```bash
# Add to /etc/kubernetes/manifests/kube-apiserver.yaml:
# --audit-policy-file=/etc/kubernetes/audit-policy.yaml
# --audit-log-path=/var/log/kubernetes/audit.log
# --audit-log-maxage=30
# --audit-log-maxbackup=10
# --audit-log-maxsize=100
```

---

## ServiceAccount Token Automount

### Disable automount on ServiceAccount
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-sa
  namespace: default
automountServiceAccountToken: false
```

### Disable automount on Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  automountServiceAccountToken: false
  serviceAccountName: my-sa
  containers:
  - name: app
    image: nginx:1.25
```

### Commands
```bash
# Create ServiceAccount
kubectl create serviceaccount <name> -n <namespace>

# Check if token is mounted in pod
kubectl exec <pod> -- ls /var/run/secrets/kubernetes.io/serviceaccount/

# Verify automount disabled
kubectl get pod <pod> -o jsonpath='{.spec.automountServiceAccountToken}'
kubectl get sa <sa-name> -o jsonpath='{.automountServiceAccountToken}'

# Get all SAs with automount enabled (default)
kubectl get sa -A -o json | \
  jq '.items[] | select(.automountServiceAccountToken != false) | "\(.metadata.namespace)/\(.metadata.name)"'
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Check permission | `kubectl auth can-i <verb> <resource>` |
| List all permissions | `kubectl auth can-i --list` |
| Impersonate SA | `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>` |
| Get ClusterRoleBindings | `kubectl get clusterrolebinding -o wide` |
| Find cluster-admin bindings | `kubectl get clusterrolebinding \| grep cluster-admin` |
| Create Role | `kubectl create role <name> --verb=get,list --resource=pods` |
| Create RoleBinding | `kubectl create rolebinding <name> --role=<role> --serviceaccount=<ns>:<sa>` |
| Disable SA automount | Set `automountServiceAccountToken: false` on SA or Pod |
| Check token in pod | `kubectl exec <pod> -- ls /var/run/secrets/kubernetes.io/serviceaccount/` |
