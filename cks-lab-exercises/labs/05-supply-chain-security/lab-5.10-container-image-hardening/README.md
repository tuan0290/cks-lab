# Lab 5.10: Container Image Hardening

## Metadata
- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 20%

## Learning Objectives
- Apply comprehensive security hardening to container images and pods
- Configure non-root users, read-only filesystems, and dropped capabilities
- Implement seccomp and AppArmor profiles for containers
- Use Pod Security Standards (PSS) to enforce hardening requirements
- Scan hardened images with Trivy to verify reduced vulnerability surface

## Prerequisites
- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- trivy installed (optional, for scanning)

## Scenario

Your security audit has identified that several production containers are running with excessive privileges and insecure configurations. You need to harden these containers by applying security best practices: running as non-root, using read-only filesystems, dropping unnecessary Linux capabilities, and applying seccomp profiles. You also need to enforce these standards using Pod Security Admission.

## Requirements

1. Create a namespace `lab-5-10` with Pod Security Standards enforced at `restricted` level
2. Create a hardened deployment `hardened-app` with all security best practices applied
3. Create a ConfigMap `hardening-checklist` documenting the hardening requirements
4. Demonstrate that a non-hardened pod is rejected by the namespace PSS policy
5. Create a Kyverno policy `enforce-container-hardening` to enforce hardening standards

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create a namespace with Pod Security Standards

```bash
# Create namespace with restricted PSS enforcement
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: lab-5-10
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
EOF
```

### Step 3: Create the hardening checklist ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: hardening-checklist
  namespace: lab-5-10
data:
  checklist.md: |
    # Container Hardening Checklist

    ## Required Settings
    - [ ] runAsNonRoot: true
    - [ ] runAsUser: non-zero UID (e.g., 65534)
    - [ ] readOnlyRootFilesystem: true
    - [ ] allowPrivilegeEscalation: false
    - [ ] capabilities.drop: [ALL]
    - [ ] seccompProfile.type: RuntimeDefault or Localhost

    ## Recommended Settings
    - [ ] Use distroless or minimal base image
    - [ ] Set resource limits (CPU and memory)
    - [ ] Use specific image tags (not :latest)
    - [ ] Scan image with Trivy before deployment
    - [ ] No privileged: true
    - [ ] No hostPID, hostIPC, hostNetwork
EOF
```

### Step 4: Create the hardened deployment

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hardened-app
  namespace: lab-5-10
  labels:
    security.hardened: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hardened-app
  template:
    metadata:
      labels:
        app: hardened-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        runAsGroup: 65534
        fsGroup: 65534
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
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
EOF
```

### Step 5: Create a Kyverno policy to enforce hardening

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-container-hardening
  annotations:
    policies.kyverno.io/title: Enforce Container Hardening
    policies.kyverno.io/description: Enforces container security hardening standards.
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: require-non-root
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-10
    validate:
      message: "Containers must not run as root. Set runAsNonRoot: true."
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
  - name: require-readonly-filesystem
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-10
    validate:
      message: "Containers must use read-only root filesystem."
      pattern:
        spec:
          containers:
          - securityContext:
              readOnlyRootFilesystem: true
  - name: drop-all-capabilities
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-10
    validate:
      message: "Containers must drop ALL capabilities."
      pattern:
        spec:
          containers:
          - securityContext:
              capabilities:
                drop:
                - ALL
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

- **Pod Security Standards**: Built-in Kubernetes admission control for pod security (Privileged, Baseline, Restricted)
- **seccompProfile**: Restricts system calls available to the container
- **capabilities**: Linux kernel capabilities that can be granted or dropped
- **readOnlyRootFilesystem**: Prevents writing to the container's root filesystem
- **runAsNonRoot**: Kubernetes-level enforcement that the container doesn't run as UID 0

## Additional Resources

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
