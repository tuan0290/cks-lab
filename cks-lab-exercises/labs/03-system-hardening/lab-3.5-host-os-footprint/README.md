# Lab 3.5: Minimizing Host OS Footprint

## Metadata

- **Domain**: 3 - System Hardening
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 10%

## Learning Objectives

- Understand the principle of minimizing the host OS attack surface
- Identify and disable unnecessary services on Kubernetes nodes
- Configure pods to avoid using host namespaces and paths
- Apply security contexts to prevent host access from containers

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

A security review found that several pods in your cluster are using host namespaces and host paths, significantly increasing the attack surface. You need to identify these pods, remediate the issues, and create policies to prevent future violations.

## Requirements

1. Create namespace `lab-3-5`
2. Create a Pod `secure-pod` that explicitly avoids all host namespace access
3. Create a Kyverno ClusterPolicy `restrict-host-access` that blocks hostPID, hostIPC, hostNetwork
4. Create a ConfigMap `host-footprint-checklist` documenting host hardening steps

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create a secure pod with no host access

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: lab-3-5
  labels:
    security: hardened
spec:
  hostPID: false
  hostIPC: false
  hostNetwork: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
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

### Step 3: Create a Kyverno policy to restrict host access

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-host-access
  annotations:
    policies.kyverno.io/title: Restrict Host Access
    policies.kyverno.io/description: Blocks pods from using host namespaces.
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: block-host-namespaces
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-3-5
    validate:
      message: "Pods must not use hostPID, hostIPC, or hostNetwork."
      pattern:
        spec:
          =(hostPID): false
          =(hostIPC): false
          =(hostNetwork): false
EOF
```

### Step 4: Create the host footprint checklist

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: host-footprint-checklist
  namespace: lab-3-5
data:
  checklist.md: |
    # Host OS Footprint Minimization Checklist
    
    ## Node-Level Hardening
    - [ ] Remove unnecessary packages (apt remove / yum remove)
    - [ ] Disable unused services (systemctl disable)
    - [ ] Close unused ports (ufw / firewalld)
    - [ ] Enable automatic security updates
    - [ ] Configure SSH hardening (disable root login, use keys)
    
    ## Pod-Level Restrictions
    - [ ] hostPID: false (default)
    - [ ] hostIPC: false (default)
    - [ ] hostNetwork: false (default)
    - [ ] No hostPath volumes (or restrict to read-only)
    - [ ] No privileged containers
    - [ ] No allowPrivilegeEscalation
    
    ## Kubernetes-Level Controls
    - [ ] Use Pod Security Standards (restricted level)
    - [ ] Use Kyverno/OPA policies to enforce restrictions
    - [ ] Enable NodeRestriction admission controller
    - [ ] Use read-only API server port (--read-only-port=0)
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

- **hostPID**: Shares the host's PID namespace — allows seeing all host processes
- **hostIPC**: Shares the host's IPC namespace — allows inter-process communication with host
- **hostNetwork**: Uses the host's network namespace — bypasses network isolation
- **Minimal footprint**: Only install/enable what is needed on nodes

## Additional Resources

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
