# Lab 4.4: Security Contexts

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Configure pod-level and container-level security contexts
- Set user/group IDs, fsGroup, and supplemental groups
- Prevent privilege escalation with allowPrivilegeEscalation: false
- Apply read-only root filesystem to containers

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

Several microservices in your cluster are running with insecure security contexts. You need to harden them by applying proper security contexts at both the pod and container level.

## Requirements

1. Create namespace `lab-4-4`
2. Create a Pod `secure-app` with:
   - Pod-level: `runAsNonRoot: true`, `runAsUser: 1000`, `fsGroup: 2000`, `seccompProfile: RuntimeDefault`
   - Container-level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`
3. Create a Pod `multi-container-app` with different security contexts per container

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create the secure pod

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: lab-4-4
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: var-cache
      mountPath: /var/cache/nginx
    - name: var-run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: var-cache
    emptyDir: {}
  - name: var-run
    emptyDir: {}
EOF
```

### Step 3: Create a multi-container pod with per-container security contexts

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-app
  namespace: lab-4-4
spec:
  securityContext:
    runAsNonRoot: true
    fsGroup: 2000
  containers:
  - name: frontend
    image: nginx:1.25
    securityContext:
      runAsUser: 101
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
        add: [NET_BIND_SERVICE]
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  - name: sidecar
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
    resources:
      limits:
        cpu: "50m"
        memory: "32Mi"
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF
```

### Step 4: Verify your solution

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

- **runAsNonRoot**: Kubernetes-level check that UID is not 0
- **runAsUser/runAsGroup**: Set the UID/GID for the container process
- **fsGroup**: Sets the GID for mounted volumes
- **allowPrivilegeEscalation**: Prevents `setuid` binaries from gaining more privileges
- **readOnlyRootFilesystem**: Mounts the container's root filesystem as read-only

## Additional Resources

- [Security Contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
