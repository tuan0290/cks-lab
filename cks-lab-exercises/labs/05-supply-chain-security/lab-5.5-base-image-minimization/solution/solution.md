# Solution: Lab 5.5 - Base Image Minimization

## Overview

This solution demonstrates how to minimize container image attack surface using distroless images, multi-stage builds, and proper security contexts.

## Step-by-Step Solution

### Step 1: Set up the environment

```bash
./setup.sh
```

### Step 2: Create the distroless-app deployment

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

**Key security settings explained:**
- `runAsNonRoot: true` — Kubernetes will reject the pod if the container tries to run as root
- `runAsUser: 65534` — The `nobody` user, a common non-root UID
- `readOnlyRootFilesystem: true` — Prevents writing to the container filesystem
- `allowPrivilegeEscalation: false` — Prevents gaining more privileges than the parent process
- `capabilities.drop: [ALL]` — Removes all Linux capabilities

### Step 3: Create the multi-stage Dockerfile ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: multistage-dockerfile
  namespace: lab-5-5
data:
  Dockerfile: |
    # Stage 1: Build stage - uses full Go image with build tools
    FROM golang:1.21-alpine AS builder
    WORKDIR /app
    COPY . .
    RUN CGO_ENABLED=0 GOOS=linux go build -o server .

    # Stage 2: Final minimal image - only the binary
    FROM gcr.io/distroless/static-debian12:nonroot
    COPY --from=builder /app/server /server
    USER nonroot:nonroot
    ENTRYPOINT ["/server"]
EOF
```

**Multi-stage build benefits:**
- Build tools (compiler, make, etc.) are NOT included in the final image
- Only the compiled binary is copied to the final stage
- Final image is typically 10-100x smaller than a build image
- No shell, package manager, or debugging tools in production

### Step 4: Create the minimal Alpine pod

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

**Note:** When using `readOnlyRootFilesystem: true`, applications that need to write files must use volume mounts. The `/tmp` emptyDir volume provides a writable temporary directory.

### Step 5: Verify the solution

```bash
./verify.sh
```

## Key Concepts Explained

### Distroless Images

Distroless images are container images that contain only the application and its runtime dependencies. They do NOT contain:
- Shell (`/bin/sh`, `/bin/bash`)
- Package managers (`apt`, `yum`, `apk`)
- Standard Unix utilities (`ls`, `cat`, `grep`)
- Any other programs not needed by the application

**Available distroless images:**
- `gcr.io/distroless/static-debian12` — For statically compiled binaries (Go, Rust)
- `gcr.io/distroless/base-debian12` — For dynamically linked binaries
- `gcr.io/distroless/java21-debian12` — For Java applications
- `gcr.io/distroless/python3-debian12` — For Python applications

### Image Size Comparison

| Base Image | Approximate Size |
|-----------|-----------------|
| ubuntu:22.04 | ~77 MB |
| debian:12 | ~117 MB |
| alpine:3.19 | ~7 MB |
| gcr.io/distroless/static-debian12 | ~2 MB |
| scratch | 0 MB |

### Security Context Best Practices

```yaml
securityContext:
  runAsNonRoot: true          # Never run as root
  runAsUser: 65534            # Use 'nobody' user
  runAsGroup: 65534           # Use 'nobody' group
  readOnlyRootFilesystem: true # Immutable filesystem
  allowPrivilegeEscalation: false # No privilege escalation
  capabilities:
    drop:
    - ALL                     # Drop all Linux capabilities
  seccompProfile:
    type: RuntimeDefault      # Use default seccomp profile
```

### CKS Exam Tips

1. **Know the distroless image names** — `gcr.io/distroless/static-debian12:nonroot` is commonly tested
2. **Security context fields** — Memorize `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation`, `capabilities.drop`
3. **Multi-stage builds** — Understand the concept even if you don't write Dockerfiles in the exam
4. **Volume mounts for writable dirs** — When `readOnlyRootFilesystem: true`, use emptyDir for `/tmp`

## Cleanup

```bash
./cleanup.sh
```
