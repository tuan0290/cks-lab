# Lab 1.9: Cluster Upgrade Security Considerations

## Metadata

- **Domain**: 1 - Cluster Setup
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand security considerations during Kubernetes cluster upgrades
- Verify cluster component versions and identify upgrade paths
- Check for deprecated API versions before upgrading
- Document pre-upgrade security checklist

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

Your cluster is running Kubernetes v1.29 and needs to be upgraded to v1.30. Before upgrading, you must perform a security audit: check for deprecated APIs in use, verify RBAC policies are still valid, and document the upgrade security checklist.

## Requirements

1. Create namespace `lab-1-9`
2. Create a ConfigMap `upgrade-security-checklist` with pre-upgrade security checks
3. Create a ConfigMap `deprecated-apis` documenting APIs removed in v1.30
4. Create a ConfigMap `cluster-version-info` with current cluster version details

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Gather cluster version information

```bash
# Get cluster version info
kubectl version -o json

# Get node versions
kubectl get nodes -o wide

# Get component statuses
kubectl get componentstatuses 2>/dev/null || echo "componentstatuses deprecated in v1.19+"
```

### Step 3: Create the cluster version info ConfigMap

```bash
SERVER_VERSION=$(kubectl version -o json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('serverVersion',{}).get('gitVersion','unknown'))" 2>/dev/null || echo "unknown")
CLIENT_VERSION=$(kubectl version --client -o json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['clientVersion']['gitVersion'])" 2>/dev/null || echo "unknown")

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-version-info
  namespace: lab-1-9
data:
  server-version: "$SERVER_VERSION"
  client-version: "$CLIENT_VERSION"
  audit-date: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
```

### Step 4: Create the deprecated APIs ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: deprecated-apis
  namespace: lab-1-9
data:
  removed-in-v1-30.md: |
    # APIs Removed in Kubernetes v1.30
    
    ## flowcontrol.apiserver.k8s.io/v1beta2
    - FlowSchema
    - PriorityLevelConfiguration
    Replacement: flowcontrol.apiserver.k8s.io/v1
    
    ## Check for deprecated API usage:
    # kubectl api-resources --verbs=list -o name | xargs -n1 kubectl get --all-namespaces -o name 2>/dev/null
    
    ## Use pluto to detect deprecated APIs:
    # pluto detect-all-in-cluster
EOF
```

### Step 5: Create the upgrade security checklist

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: upgrade-security-checklist
  namespace: lab-1-9
data:
  checklist.md: |
    # Pre-Upgrade Security Checklist
    
    ## Before Upgrading
    - [ ] Backup etcd data
    - [ ] Review release notes for security changes
    - [ ] Check for deprecated/removed APIs
    - [ ] Verify RBAC policies compatibility
    - [ ] Test upgrade in staging environment
    - [ ] Review new default security settings
    
    ## Security Changes to Review
    - [ ] New admission controllers enabled by default
    - [ ] Changed default RBAC permissions
    - [ ] New Pod Security Standards behavior
    - [ ] Updated TLS cipher suites
    - [ ] New audit policy defaults
    
    ## Post-Upgrade Verification
    - [ ] Verify all nodes upgraded successfully
    - [ ] Run kube-bench after upgrade
    - [ ] Verify all workloads running correctly
    - [ ] Check audit logs for errors
    - [ ] Verify RBAC still works as expected
EOF
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

- **Upgrade path**: Kubernetes supports upgrading one minor version at a time (e.g., 1.29 → 1.30)
- **Deprecated APIs**: APIs removed in new versions must be migrated before upgrading
- **etcd backup**: Always backup etcd before upgrading the control plane
- **kubeadm upgrade**: Standard tool for upgrading kubeadm-managed clusters

## Additional Resources

- [Kubernetes Upgrade Guide](https://kubernetes.io/docs/tasks/administer-cluster/cluster-upgrade/)
- [Deprecated API Migration Guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)
