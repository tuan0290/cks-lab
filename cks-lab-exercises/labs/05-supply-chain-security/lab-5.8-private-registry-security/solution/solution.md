# Solution: Lab 5.8 - Private Registry Security

## Overview

This solution demonstrates how to configure Kubernetes to use a private container registry with authentication and enforce registry restrictions using Kyverno policies.

## Step-by-Step Solution

### Step 1: Set up the environment

```bash
./setup.sh
```

### Step 2: Create the registry authentication secret

```bash
kubectl create secret docker-registry registry-credentials \
  --docker-server=registry.example.com \
  --docker-username=lab-user \
  --docker-password=lab-password-secure \
  --docker-email=lab@example.com \
  -n lab-5-8
```

**Verify the secret was created:**
```bash
kubectl get secret registry-credentials -n lab-5-8 -o yaml
# The .dockerconfigjson data is base64 encoded
kubectl get secret registry-credentials -n lab-5-8 -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

### Step 3: Configure the default ServiceAccount

```bash
kubectl patch serviceaccount default -n lab-5-8 \
  -p '{"imagePullSecrets": [{"name": "registry-credentials"}]}'

# Verify
kubectl get serviceaccount default -n lab-5-8 -o yaml
```

### Step 4: Create the registry restriction policy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
  annotations:
    policies.kyverno.io/title: Restrict Image Registries
    policies.kyverno.io/description: Restricts container images to approved registries only.
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: validate-registries
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-8
    validate:
      message: "Images must be from approved registries: registry.example.com, gcr.io/distroless"
      pattern:
        spec:
          containers:
          - image: "registry.example.com/* | gcr.io/distroless/*"
EOF
```

### Step 5: Create the deployment with imagePullSecrets

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: private-registry-app
  namespace: lab-5-8
  annotations:
    security.registry/source: "registry.example.com"
    security.registry/scanned: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: private-registry-app
  template:
    metadata:
      labels:
        app: private-registry-app
    spec:
      imagePullSecrets:
      - name: registry-credentials
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
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
            memory: "32Mi"
EOF
```

### Step 6: Create the dedicated ServiceAccount

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: lab-5-8
imagePullSecrets:
- name: registry-credentials
EOF
```

## Registry Secret Types

| Secret Type | Use Case |
|-------------|----------|
| `kubernetes.io/dockerconfigjson` | Docker registry credentials (modern) |
| `kubernetes.io/dockercfg` | Docker registry credentials (legacy) |

## imagePullSecrets Precedence

1. **Pod spec** `imagePullSecrets` — Highest priority, applies to that pod only
2. **ServiceAccount** `imagePullSecrets` — Applies to all pods using that SA
3. **Default ServiceAccount** `imagePullSecrets` — Applies to all pods in namespace using default SA

## CKS Exam Tips

1. **Secret creation command**: `kubectl create secret docker-registry` — memorize this
2. **Secret type**: `kubernetes.io/dockerconfigjson` — know this type
3. **Patching SA**: `kubectl patch serviceaccount default -p '{"imagePullSecrets": [...]}'`
4. **Registry restriction**: Use Kyverno `validate` rule with image pattern matching

## Cleanup

```bash
./cleanup.sh
```
