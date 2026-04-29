# Lab 5.12: Admission Controllers for Supply Chain Enforcement

## Metadata
- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives
- Understand how admission controllers enforce supply chain security policies
- Configure Kyverno policies to enforce multiple supply chain requirements simultaneously
- Implement image mutation policies to add security annotations automatically
- Create comprehensive supply chain enforcement using multiple Kyverno rules
- Understand the difference between validating and mutating admission webhooks

## Prerequisites
- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Kyverno installed in the cluster

## Scenario

Your organization needs a comprehensive supply chain security enforcement system. All deployments must pass multiple security gates: images must come from approved registries, must have scan annotations, must use non-root users, and must have resource limits. You need to configure Kyverno as the admission controller to enforce all these requirements and automatically mutate deployments to add required security labels.

## Requirements

1. Create a namespace `lab-5-12` for this lab
2. Create a Kyverno `ClusterPolicy` `supply-chain-validate` with multiple validation rules:
   - Require images from approved registries
   - Require scan status annotation
   - Require non-root security context
3. Create a Kyverno `ClusterPolicy` `supply-chain-mutate` that automatically adds:
   - Security labels to pods
   - Default resource limits if not set
4. Create a deployment `compliant-app` that passes all supply chain checks
5. Create a ConfigMap `supply-chain-config` with the enforcement configuration

## Instructions

### Step 1: Set up the lab environment

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

### Step 3: Create the validating admission policy

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

### Step 4: Create the mutating admission policy

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

- **Validating Admission Webhook**: Validates resources and can reject them (Kyverno `validate` rules)
- **Mutating Admission Webhook**: Modifies resources before they are stored (Kyverno `mutate` rules)
- **Admission Controller Order**: Mutating webhooks run before validating webhooks
- **patchStrategicMerge**: Kyverno mutation strategy that merges patches with existing spec
- **`+(field)`**: Kyverno syntax to add a field only if it doesn't already exist

## Additional Resources

- [Kyverno Policies](https://kyverno.io/docs/writing-policies/)
- [Kubernetes Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Kyverno Mutating Policies](https://kyverno.io/docs/writing-policies/mutate/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
