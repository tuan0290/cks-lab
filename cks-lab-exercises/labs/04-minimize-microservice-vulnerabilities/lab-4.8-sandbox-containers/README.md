# Lab 4.8: Sandbox Containers with gVisor

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Understand container sandbox technologies (gVisor, Kata Containers)
- Configure RuntimeClass for sandbox runtimes
- Deploy pods using a sandboxed runtime
- Understand the security benefits of kernel isolation

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- gVisor (runsc) installed on nodes (optional for documentation lab)

## Scenario

Your security team requires that untrusted workloads run in a sandboxed environment to prevent kernel exploits. You need to configure a RuntimeClass for gVisor and deploy a pod using it.

## Requirements

1. Create namespace `lab-4-8`
2. Create a RuntimeClass `gvisor` with handler `runsc`
3. Create a Pod `sandboxed-app` using the `gvisor` RuntimeClass
4. Create a ConfigMap `sandbox-comparison` documenting sandbox technologies

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create the gVisor RuntimeClass

```bash
cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeClassification:
    tolerations:
    - key: "sandbox"
      operator: "Equal"
      value: "gvisor"
      effect: "NoSchedule"
EOF
```

### Step 3: Create a pod using the sandboxed runtime

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-app
  namespace: lab-4-8
spec:
  runtimeClassName: gvisor
  containers:
  - name: app
    image: nginx:1.25
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF
```

### Step 4: Create sandbox comparison documentation

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: sandbox-comparison
  namespace: lab-4-8
data:
  comparison.md: |
    # Container Sandbox Technologies
    
    ## gVisor (Google)
    - Intercepts system calls in user space
    - Provides kernel isolation without full VM overhead
    - Handler: runsc
    - Use case: Untrusted workloads, multi-tenant environments
    
    ## Kata Containers
    - Runs containers in lightweight VMs
    - Full kernel isolation
    - Handler: kata-runtime or kata-qemu
    - Use case: Maximum isolation requirements
    
    ## Standard runc
    - Shares host kernel
    - No additional isolation
    - Handler: runc (default)
    - Use case: Trusted workloads
    
    ## RuntimeClass Usage
    spec:
      runtimeClassName: gvisor  # or kata-containers
EOF
```

### Step 5: Verify your solution

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

- **RuntimeClass**: Kubernetes resource for selecting container runtime
- **gVisor**: User-space kernel that intercepts syscalls (Google)
- **Kata Containers**: VM-based container isolation
- **handler**: The name of the runtime on the node (e.g., `runsc` for gVisor)

## Additional Resources

- [RuntimeClass](https://kubernetes.io/docs/concepts/containers/runtime-class/)
- [gVisor](https://gvisor.dev/)
- [Kata Containers](https://katacontainers.io/)
