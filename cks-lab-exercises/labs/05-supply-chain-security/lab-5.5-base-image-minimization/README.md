# Lab 5.5: Base Image Minimization

## Metadata
- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 20%

## Learning Objectives
- Understand the security benefits of minimal base images
- Build distroless container images to reduce attack surface
- Implement multi-stage Docker builds to minimize final image size
- Compare attack surface between standard and minimal images
- Apply image minimization best practices for CKS exam scenarios

## Prerequisites
- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Docker or containerd available
- Basic understanding of Dockerfiles and container images

## Scenario

Your security team has identified that several production workloads are using full OS base images (e.g., `ubuntu:latest`, `debian:latest`) which contain hundreds of unnecessary packages and binaries. This significantly increases the attack surface. You need to migrate these workloads to use minimal base images (distroless or Alpine-based) and implement multi-stage builds to ensure only the necessary artifacts are included in the final image.

## Requirements

1. Create a Kubernetes deployment using a distroless base image (`gcr.io/distroless/static-debian12`)
2. Create a multi-stage build Dockerfile that produces a minimal final image
3. Deploy a pod that runs as non-root user with a read-only root filesystem
4. Verify the image does not contain a shell (`/bin/sh` or `/bin/bash`)
5. Configure the pod with appropriate security context settings

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources for the lab.

### Step 2: Create a deployment with distroless image

Create a deployment using a distroless base image with proper security context:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: distroless-app
  namespace: lab-5-5
spec:
  replicas: 1
  selector:
    matchLabels:
      app: distroless-app
  template:
    metadata:
      labels:
        app: distroless-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        runAsGroup: 65534
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

### Step 3: Create a ConfigMap with Dockerfile demonstrating multi-stage build

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: multistage-dockerfile
  namespace: lab-5-5
data:
  Dockerfile: |
    # Stage 1: Build stage
    FROM golang:1.21-alpine AS builder
    WORKDIR /app
    COPY . .
    RUN CGO_ENABLED=0 GOOS=linux go build -o server .

    # Stage 2: Final minimal image
    FROM gcr.io/distroless/static-debian12:nonroot
    COPY --from=builder /app/server /server
    USER nonroot:nonroot
    ENTRYPOINT ["/server"]
EOF
```

### Step 4: Create a pod with minimal Alpine image and security hardening

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: minimal-alpine-pod
  namespace: lab-5-5
  labels:
    app: minimal-alpine
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: alpine:3.19
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
EOF
```

### Step 5: Create a Kyverno policy to enforce minimal base images

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-base-images
  annotations:
    policies.kyverno.io/title: Restrict Base Images
    policies.kyverno.io/description: Restricts container images to approved minimal base images only.
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: check-base-image
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-5
    validate:
      message: "Only distroless or Alpine-based images are allowed."
      pattern:
        spec:
          containers:
          - image: "gcr.io/distroless/* | */alpine:* | alpine:*"
EOF
```

### Step 6: Verify your solution

Use the verification script to check if your configuration is correct:

```bash
./verify.sh
```

Review any failed checks and make corrections as needed.

## Verification

Run the verification script to check your solution:

```bash
./verify.sh
```

All checks should pass before proceeding.

## Cleanup

After completing the lab, clean up the resources:

```bash
./cleanup.sh
```

## Key Concepts

- **Distroless images**: Images that contain only the application and its runtime dependencies, no shell, package manager, or other OS utilities
- **Multi-stage builds**: Docker build technique that uses multiple FROM statements to produce a minimal final image
- **Attack surface reduction**: Fewer packages = fewer potential vulnerabilities
- **Non-root containers**: Running as non-root reduces privilege escalation risk

## Additional Resources

- [Distroless Images](https://github.com/GoogleContainerTools/distroless)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
