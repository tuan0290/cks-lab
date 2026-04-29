# Lab 4.12: Runtime Security with Falco Integration

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Understand runtime security monitoring for microservices
- Configure Falco rules to detect suspicious microservice behavior
- Implement immutable containers using readOnlyRootFilesystem
- Detect and respond to runtime security events

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Falco installed (optional)

## Scenario

Your microservices need runtime security monitoring. You need to configure immutable containers, set up Falco rules to detect suspicious behavior, and document the runtime security posture.

## Requirements

1. Create namespace `lab-4-12`
2. Create a Deployment `immutable-app` with `readOnlyRootFilesystem: true` and all capabilities dropped
3. Create a ConfigMap `falco-microservice-rules` with Falco rules for microservice monitoring
4. Create a ConfigMap `runtime-security-policy` documenting the runtime security approach

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-4-12`.

2. **Task**: Create a Deployment named `immutable-app` in namespace `lab-4-12` with 2 replicas using image `nginx:1.25` where every container has:
   - `readOnlyRootFilesystem: true`
   - `allowPrivilegeEscalation: false`
   - `capabilities.drop: [ALL]`
   - `securityContext.runAsNonRoot: true`, `runAsUser: 1000`
   - `securityContext.seccompProfile.type: RuntimeDefault`
   - Mount `emptyDir` volumes for `/tmp`, `/var/cache/nginx`, `/var/run`

3. **Task**: Create a ConfigMap named `falco-microservice-rules` in namespace `lab-4-12` containing Falco rules YAML for detecting:
   - Shell spawning in microservice containers
   - Writes to immutable container filesystem
   - Unexpected outbound connections

4. **Task**: Create a ConfigMap named `runtime-security-policy` in namespace `lab-4-12` documenting the runtime security policy including immutability requirements, monitoring requirements, and incident response procedures.

5. **Task**: Verify the deployment has `readOnlyRootFilesystem: true`:
   ```bash
   kubectl get deployment immutable-app -n lab-4-12 \
     -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}'
   # Expected: true
   ```

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immutable-app
  namespace: lab-4-12
spec:
  replicas: 2
  selector:
    matchLabels:
      app: immutable-app
  template:
    metadata:
      labels:
        app: immutable-app
    spec:
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
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
EOF
```

### Step 3: Create Falco rules for microservice monitoring

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-microservice-rules
  namespace: lab-4-12
data:
  microservice-rules.yaml: |
    # Falco rules for microservice security monitoring
    
    - rule: Unexpected outbound connection from microservice
      desc: Detect unexpected outbound connections from microservice pods
      condition: >
        outbound and
        container and
        k8s.ns.name = "lab-4-12" and
        not fd.sport in (80, 443, 8080, 8443)
      output: >
        Unexpected outbound connection from microservice
        (user=%user.name command=%proc.cmdline connection=%fd.name
        pod=%k8s.pod.name ns=%k8s.ns.name)
      priority: WARNING
    
    - rule: Write to immutable container filesystem
      desc: Detect writes to containers with readOnlyRootFilesystem
      condition: >
        open_write and
        container and
        k8s.ns.name = "lab-4-12" and
        not fd.name startswith /tmp and
        not fd.name startswith /var/cache and
        not fd.name startswith /var/run
      output: >
        Write to immutable container filesystem
        (user=%user.name file=%fd.name pod=%k8s.pod.name)
      priority: ERROR
    
    - rule: Shell spawned in microservice container
      desc: Detect shell execution in microservice containers
      condition: >
        spawned_process and
        container and
        k8s.ns.name = "lab-4-12" and
        proc.name in (shell_binaries)
      output: >
        Shell spawned in microservice container
        (user=%user.name shell=%proc.name pod=%k8s.pod.name)
      priority: CRITICAL
EOF
```

### Step 4: Create runtime security policy documentation

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: runtime-security-policy
  namespace: lab-4-12
data:
  policy.md: |
    # Runtime Security Policy for Microservices
    
    ## Immutability Requirements
    - readOnlyRootFilesystem: true for all containers
    - Only /tmp, /var/cache, /var/run writable via emptyDir
    - No privileged containers
    - Drop ALL capabilities
    
    ## Monitoring Requirements
    - Falco deployed on all nodes
    - Alert on: shell spawning, unexpected writes, unusual network connections
    - Log all CRITICAL and ERROR events to SIEM
    
    ## Response Procedures
    1. CRITICAL alert: Isolate pod immediately (kubectl label pod quarantine=true)
    2. ERROR alert: Investigate within 1 hour
    3. WARNING alert: Review within 24 hours
    
    ## Compliance
    - CIS Kubernetes Benchmark: Section 5 (Policies)
    - NIST SP 800-190: Container Security Guide
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

- **Immutable containers**: readOnlyRootFilesystem prevents runtime modifications
- **Falco**: Runtime security monitoring using eBPF/kernel module
- **Defense in depth**: Combine immutability + monitoring + network policies
- **Incident response**: Automated quarantine of compromised pods

## Additional Resources

- [Falco](https://falco.org/)
- [Immutable Containers](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
