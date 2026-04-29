# Solution: Lab 5.12 - Admission Controllers for Supply Chain Enforcement

## Overview

This solution demonstrates how to use Kyverno as an admission controller to enforce comprehensive supply chain security requirements through both validating and mutating policies.

## Step-by-Step Solution

### Step 1: Set up the environment

```bash
./setup.sh
```

### Step 2: Create the supply chain configuration

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: supply-chain-config
  namespace: lab-5-12
data:
  approved-registries: "gcr.io/distroless,registry.k8s.io,docker.io/library"
  require-scan-annotation: "true"
  require-non-root: "true"
  require-resource-limits: "true"
  require-image-signature: "false"
  enforcement-mode: "audit"
EOF
```

### Step 3: Create the validating policy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: supply-chain-validate
  annotations:
    policies.kyverno.io/title: Supply Chain Validation
    policies.kyverno.io/description: Validates supply chain security requirements for all pods.
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: require-approved-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-12
    validate:
      message: "Images must be from approved registries."
      pattern:
        spec:
          containers:
          - image: "gcr.io/* | registry.k8s.io/* | docker.io/library/*"
  - name: require-scan-annotation
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-12
    validate:
      message: "Pods must have security.scan/status annotation."
      pattern:
        metadata:
          annotations:
            security.scan/status: "?*"
  - name: require-non-root
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-12
    validate:
      message: "Containers must not run as root."
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
  - name: require-resource-limits
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-12
    validate:
      message: "Containers must have resource limits defined."
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: "?*"
                cpu: "?*"
EOF
```

### Step 4: Create the mutating policy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: supply-chain-mutate
  annotations:
    policies.kyverno.io/title: Supply Chain Mutation
    policies.kyverno.io/description: Automatically adds supply chain security labels and defaults.
spec:
  rules:
  - name: add-supply-chain-labels
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-12
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            security.supply-chain/enforced: "true"
            security.supply-chain/policy-version: "v1"
  - name: add-default-seccomp
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-12
    mutate:
      patchStrategicMerge:
        spec:
          securityContext:
            +(seccompProfile):
              type: RuntimeDefault
EOF
```

### Step 5: Create the compliant deployment

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compliant-app
  namespace: lab-5-12
  annotations:
    security.scan/status: "passed"
    security.scan/tool: "trivy"
    security.supply-chain/compliant: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: compliant-app
  template:
    metadata:
      labels:
        app: compliant-app
      annotations:
        security.scan/status: "passed"
        security.scan/tool: "trivy"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        runAsGroup: 65534
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: gcr.io/distroless/static-debian12:nonroot
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        resources:
          limits:
            cpu: "100m"
            memory: "64Mi"
          requests:
            cpu: "50m"
            memory: "32Mi"
EOF
```

## Admission Controller Flow

```
kubectl apply -f deployment.yaml
         |
         v
  [API Server receives request]
         |
         v
  [Authentication & Authorization]
         |
         v
  [Mutating Admission Webhooks]  ← Kyverno mutate rules run here
  (supply-chain-mutate policy)
         |
         v
  [Object Schema Validation]
         |
         v
  [Validating Admission Webhooks] ← Kyverno validate rules run here
  (supply-chain-validate policy)
         |
         v
  [Persisted to etcd]
```

## Kyverno Policy Patterns

### Validate Pattern Wildcards
```yaml
# "?*" means "any non-empty string"
pattern:
  metadata:
    annotations:
      security.scan/status: "?*"

# "|" means OR
pattern:
  spec:
    containers:
    - image: "gcr.io/* | docker.io/library/*"
```

### Mutate patchStrategicMerge
```yaml
mutate:
  patchStrategicMerge:
    metadata:
      labels:
        new-label: "value"    # Always sets this label
    spec:
      securityContext:
        +(seccompProfile):    # "+" prefix: only add if not already present
          type: RuntimeDefault
```

### Switching from Audit to Enforce
```bash
# Change policy to enforce mode (blocks non-compliant resources)
kubectl patch clusterpolicy supply-chain-validate \
  --type=merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

## Checking Policy Reports

```bash
# View policy violations
kubectl get policyreport -n lab-5-12
kubectl get clusterpolicyreport

# View detailed violations
kubectl describe policyreport -n lab-5-12
```

## CKS Exam Tips

1. **Admission controller order**: Mutating runs BEFORE validating
2. **Kyverno rule types**: `validate`, `mutate`, `generate`, `verifyImages`
3. **validationFailureAction**: `Audit` (log only) vs `Enforce` (block)
4. **background: true**: Applies policy to existing resources too
5. **patchStrategicMerge**: The most common mutation strategy
6. **`+(field)` syntax**: Adds field only if not already present

## Cleanup

```bash
./cleanup.sh
```
