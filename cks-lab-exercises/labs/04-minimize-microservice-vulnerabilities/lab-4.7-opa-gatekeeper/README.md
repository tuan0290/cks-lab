# Lab 4.7: OPA Gatekeeper Policy Enforcement

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Install and configure OPA Gatekeeper
- Create ConstraintTemplates and Constraints for policy enforcement
- Enforce required labels on namespaces and pods
- Test policy enforcement with compliant and non-compliant resources

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

Your organization requires all pods to have specific labels for cost tracking and ownership. You need to use OPA Gatekeeper to enforce these labeling requirements.

## Requirements

1. Create namespace `lab-4-7`
2. Create a ConstraintTemplate `K8sRequiredLabels` that enforces required labels
3. Create a Constraint `require-app-label` requiring the `app` label on all pods in `lab-4-7`
4. Create a compliant Pod `labeled-pod` with the required label
5. Create a ConfigMap `gatekeeper-policy-docs` documenting the policy

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create the ConstraintTemplate

```bash
cat <<EOF | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredlabels
      violation[{"msg": msg}] {
        provided := {label | input.review.object.metadata.labels[label]}
        required := {label | label := input.parameters.labels[_]}
        missing := required - provided
        count(missing) > 0
        msg := sprintf("Missing required labels: %v", [missing])
      }
EOF
```

### Step 3: Create the Constraint

```bash
cat <<EOF | kubectl apply -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-label
spec:
  enforcementAction: deny
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - lab-4-7
  parameters:
    labels:
    - app
EOF
```

### Step 4: Create a compliant pod

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: labeled-pod
  namespace: lab-4-7
  labels:
    app: my-app
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF
```

### Step 5: Create policy documentation

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gatekeeper-policy-docs
  namespace: lab-4-7
data:
  policy.md: |
    # OPA Gatekeeper Policy: require-app-label
    
    ## Purpose
    All pods in lab-4-7 must have the 'app' label.
    
    ## Enforcement
    Action: deny (blocks non-compliant pods)
    
    ## Compliant Example
    metadata:
      labels:
        app: my-app
    
    ## Non-compliant Example (will be blocked)
    metadata:
      labels:
        name: my-app  # Missing 'app' label
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

- **ConstraintTemplate**: Defines the policy logic in Rego
- **Constraint**: Instantiates a ConstraintTemplate with specific parameters and scope
- **enforcementAction: deny**: Blocks non-compliant resources (vs `warn` or `dryrun`)
- **Rego**: Policy language used by OPA

## Additional Resources

- [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/)
- [Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library)
