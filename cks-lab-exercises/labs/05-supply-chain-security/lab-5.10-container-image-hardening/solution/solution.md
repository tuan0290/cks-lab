# Solution: Lab 5.10 - Container Image Hardening

## Overview

This solution demonstrates comprehensive container security hardening using Pod Security Standards, security contexts, and Kyverno policies.

## Step-by-Step Solution

### Step 1: Set up the environment

```bash
./setup.sh
```

### Step 2: Update namespace with restricted PSS

```bash
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

### Step 3: Create the hardening checklist

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

### Step 5: Create the Kyverno hardening policy

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

## Pod Security Standards Reference

### Restricted Profile Requirements

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault  # or Localhost
  containers:
  - securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      # Optional but recommended:
      readOnlyRootFilesystem: true
      runAsUser: 65534
```

### PSS Labels Reference

```bash
# Enforce mode - blocks non-compliant pods
kubectl label namespace myns pod-security.kubernetes.io/enforce=restricted

# Warn mode - allows but warns
kubectl label namespace myns pod-security.kubernetes.io/warn=restricted

# Audit mode - allows but logs
kubectl label namespace myns pod-security.kubernetes.io/audit=restricted
```

## Scanning with Trivy

```bash
# Scan image for vulnerabilities
trivy image gcr.io/distroless/static-debian12:nonroot

# Compare attack surface
trivy image ubuntu:22.04 | grep -c "CRITICAL\|HIGH"
trivy image gcr.io/distroless/static-debian12:nonroot | grep -c "CRITICAL\|HIGH"
```

## CKS Exam Tips

1. **PSS labels**: Know all three modes (enforce, warn, audit) and three levels (privileged, baseline, restricted)
2. **Security context fields**: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation`, `capabilities.drop`, `seccompProfile`
3. **Restricted PSS**: Requires seccompProfile — this is a common exam gotcha
4. **emptyDir for /tmp**: When using readOnlyRootFilesystem, mount emptyDir for writable directories

## Cleanup

```bash
./cleanup.sh
```
