# Lab 2.9: NodeRestriction Admission Controller

## Metadata

- **Domain**: 2 - Cluster Hardening
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand what the NodeRestriction admission controller does
- Verify NodeRestriction is enabled on the API server
- Understand which labels kubelets are restricted from setting
- Test node labeling restrictions

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

You need to verify that the NodeRestriction admission controller is properly configured to prevent kubelets from modifying nodes or pods outside their scope. You also need to document the restrictions it enforces and test node label restrictions.

## Requirements

1. Create namespace `lab-2-9`
2. Create a ConfigMap `node-restriction-config` documenting what NodeRestriction enforces
3. Apply a label `security-zone=production` to a node (as cluster admin — this is allowed)
4. Create a ConfigMap `node-labels-test` documenting which labels kubelets cannot set

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-2-9`.

2. **Task**: Get the name of the first node and apply label `security-zone=production` to it:
   ```bash
   NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
   kubectl label node "$NODE" security-zone=production --overwrite
   kubectl get node "$NODE" --show-labels | grep security-zone
   ```

3. **Task**: Create a ConfigMap named `node-restriction-config` in namespace `lab-2-9` documenting:
   - What the NodeRestriction admission controller prevents kubelets from doing
   - Which label prefixes are restricted (`node-restriction.kubernetes.io/`)
   - Why this matters for security (privilege escalation via labels)

4. **Task**: Create a ConfigMap named `node-labels-test` in namespace `lab-2-9` documenting:
   - Labels a cluster admin CAN set (any label)
   - Labels a kubelet CANNOT set (e.g., `node-restriction.kubernetes.io/*`)
   - The test result from step 2

5. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Verify NodeRestriction is enabled

```bash
# Check API server flags (on control plane)
# grep NodeRestriction /etc/kubernetes/manifests/kube-apiserver.yaml

# Verify by checking node labels (cluster admin can set any label)
kubectl get nodes --show-labels
```

### Step 3: Label a node as cluster admin

```bash
# Get a node name
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Node: $NODE"

# Apply a security label (allowed as cluster admin)
kubectl label node "$NODE" security-zone=production --overwrite

# Verify
kubectl get node "$NODE" --show-labels | grep security-zone
```

### Step 4: Create the NodeRestriction config documentation

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-restriction-config
  namespace: lab-2-9
data:
  restrictions.md: |
    # NodeRestriction Admission Controller
    
    ## What it does
    Limits the Node and Pod objects a kubelet can modify.
    
    ## Kubelet CAN:
    - Modify its own Node object
    - Modify Pods bound to its node
    - Set labels with prefix: node.kubernetes.io/
    - Set labels with prefix: kubelet.kubernetes.io/
    
    ## Kubelet CANNOT:
    - Modify other nodes
    - Modify pods on other nodes
    - Set labels with prefix: node-restriction.kubernetes.io/
    - Set arbitrary labels (prevents privilege escalation via labels)
    
    ## Why it matters
    Without NodeRestriction, a compromised kubelet could:
    - Label itself as a master node
    - Modify other nodes to attract sensitive workloads
    - Escalate privileges via node labels used in scheduling
    
    ## Enabling
    Add NodeRestriction to --enable-admission-plugins in kube-apiserver
EOF
```

### Step 5: Create node labels test documentation

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
LABELS=$(kubectl get node "$NODE" --show-labels -o jsonpath='{.metadata.labels}' 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('\n'.join(f'{k}: {v}' for k,v in list(d.items())[:5]))" 2>/dev/null || echo "Cannot parse labels")

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-labels-test
  namespace: lab-2-9
data:
  test-results.md: |
    # Node Label Restriction Tests
    
    ## Test 1: Cluster admin can set any label
    Command: kubectl label node $NODE security-zone=production
    Result: SUCCESS (cluster admin bypasses NodeRestriction)
    
    ## Test 2: Kubelet cannot set node-restriction.kubernetes.io/ labels
    This prefix is reserved and blocked by NodeRestriction
    
    ## Test 3: Kubelet cannot label other nodes
    A kubelet can only modify its own node object
    
    ## Current node labels (sample):
    $LABELS
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

- **NodeRestriction**: Admission controller that limits kubelet API access
- **node-restriction.kubernetes.io/**: Label prefix that kubelets cannot set
- **Kubelet identity**: Kubelets authenticate as `system:node:<nodename>`
- **Privilege escalation via labels**: Without restriction, kubelets could label themselves as masters

## Additional Resources

- [NodeRestriction Admission Controller](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction)
- [Kubelet Authentication](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/)
