# Lab 5.8: Private Registry Security

## Metadata
- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 20%

## Learning Objectives
- Configure Kubernetes to use a private container registry
- Create and manage registry authentication secrets (imagePullSecrets)
- Implement Kyverno policies to restrict image sources to approved registries
- Understand registry security best practices
- Configure service accounts with imagePullSecrets

## Prerequisites
- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Basic understanding of container registries

## Scenario

Your organization has set up a private container registry to control which images can be used in the cluster. All production workloads must pull images from this approved private registry, and direct pulls from public registries like Docker Hub must be blocked. You need to configure authentication for the private registry and enforce registry restrictions using admission control policies.

## Requirements

1. Create a namespace `lab-5-8` for this lab
2. Create an `imagePullSecret` named `registry-credentials` for private registry authentication
3. Configure the default ServiceAccount to use the imagePullSecret
4. Create a Kyverno policy `restrict-image-registries` that only allows images from approved registries
5. Create a deployment `private-registry-app` that uses the private registry credentials
6. Verify that pods without proper registry credentials are blocked

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-5-8`.

2. **Task**: Create an `imagePullSecret` named `registry-credentials` in namespace `lab-5-8`:
   ```bash
   kubectl create secret docker-registry registry-credentials \
     --docker-server=registry.example.com \
     --docker-username=lab-user \
     --docker-password=lab-password-secure \
     --docker-email=lab@example.com \
     -n lab-5-8
   ```

3. **Task**: Patch the `default` ServiceAccount in namespace `lab-5-8` to automatically use `registry-credentials`:
   ```bash
   kubectl patch serviceaccount default -n lab-5-8 \
     -p '{"imagePullSecrets": [{"name": "registry-credentials"}]}'
   ```

4. **Task**: Create a Kyverno ClusterPolicy named `restrict-image-registries` in Audit mode that only allows images from `registry.example.com/*` or `gcr.io/distroless/*` in namespace `lab-5-8`.

5. **Task**: Create a Deployment named `private-registry-app` in namespace `lab-5-8` using image `gcr.io/distroless/static-debian12:nonroot` with `imagePullSecrets: [{name: registry-credentials}]`.

6. **Task**: Create a ServiceAccount named `app-service-account` in namespace `lab-5-8` with `imagePullSecrets: [{name: registry-credentials}]`.

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create the registry authentication secret

```bash
# Create imagePullSecret for private registry
# (Using a simulated registry URL for the lab)
kubectl create secret docker-registry registry-credentials \
  --docker-server=registry.example.com \
  --docker-username=lab-user \
  --docker-password=lab-password-secure \
  --docker-email=lab@example.com \
  -n lab-5-8 \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 3: Configure the default ServiceAccount with imagePullSecrets

```bash
# Patch the default service account to use the registry credentials
kubectl patch serviceaccount default -n lab-5-8 \
  -p '{"imagePullSecrets": [{"name": "registry-credentials"}]}'

# Verify the patch
kubectl get serviceaccount default -n lab-5-8 -o yaml
```

### Step 4: Create a Kyverno policy to restrict image registries

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

### Step 5: Create a deployment using the private registry

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

### Step 6: Create a second ServiceAccount with explicit imagePullSecrets

```bash
# Create a dedicated service account for the application
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

### Step 7: Verify your solution

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

- **imagePullSecrets**: Kubernetes secrets of type `kubernetes.io/dockerconfigjson` used for registry authentication
- **ServiceAccount imagePullSecrets**: Automatically applied to all pods using that service account
- **Registry restriction policies**: Kyverno policies that validate image sources
- **docker-registry secret**: The secret type for container registry credentials

## Additional Resources

- [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)
- [Configure Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Kyverno Registry Policies](https://kyverno.io/policies/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
