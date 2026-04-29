# Lab 1.4: CIS Benchmark with kube-bench

## Metadata

- **Domain**: 1 - Cluster Setup
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Run kube-bench to audit Kubernetes cluster against CIS benchmarks
- Interpret kube-bench output and identify FAIL/WARN items
- Remediate common CIS benchmark failures on API server and kubelet
- Understand CIS Kubernetes Benchmark sections and scoring

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kube-bench installed or available as a container image

## Scenario

Your security team requires the Kubernetes cluster to comply with CIS Kubernetes Benchmark v1.8. You need to run kube-bench to identify compliance failures, then remediate the most critical findings related to the API server configuration and kubelet settings.

## Requirements

1. Run kube-bench against the cluster and capture the output
2. Create a ConfigMap `cis-benchmark-results` in namespace `lab-1-4` with a summary of findings
3. Create a ConfigMap `cis-remediation-plan` documenting at least 3 remediation steps
4. Verify the namespace `lab-1-4` exists with label `security=cis-benchmark`

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Run kube-bench as a Job

```bash
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
  namespace: lab-1-4
spec:
  template:
    spec:
      hostPID: true
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      restartPolicy: Never
      volumes:
      - name: var-lib-etcd
        hostPath:
          path: "/var/lib/etcd"
      - name: var-lib-kubelet
        hostPath:
          path: "/var/lib/kubelet"
      - name: var-lib-kube-scheduler
        hostPath:
          path: "/var/lib/kube-scheduler"
      - name: var-lib-kube-controller-manager
        hostPath:
          path: "/var/lib/kube-controller-manager"
      - name: etc-systemd
        hostPath:
          path: "/etc/systemd"
      - name: lib-systemd
        hostPath:
          path: "/lib/systemd/"
      - name: etc-kubernetes
        hostPath:
          path: "/etc/kubernetes"
      - name: usr-bin
        hostPath:
          path: "/usr/bin"
      containers:
      - name: kube-bench
        image: aquasec/kube-bench:latest
        command: ["kube-bench", "--json"]
        volumeMounts:
        - name: var-lib-etcd
          mountPath: /var/lib/etcd
          readOnly: true
        - name: var-lib-kubelet
          mountPath: /var/lib/kubelet
          readOnly: true
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
          readOnly: true
        - name: usr-bin
          mountPath: /usr/local/mount-from-host/bin
          readOnly: true
EOF
```

### Step 3: Create the CIS benchmark results ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cis-benchmark-results
  namespace: lab-1-4
data:
  summary: |
    CIS Kubernetes Benchmark v1.8 Scan Results
    ==========================================
    Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    Section 1 - Control Plane Components
    PASS: 1.1.1 API server pod file permissions
    FAIL: 1.2.1 Anonymous auth should be disabled
    WARN: 1.2.6 Audit log path should be set
    
    Section 4 - Worker Nodes
    PASS: 4.1.1 kubelet service file permissions
    FAIL: 4.2.1 Anonymous auth should be disabled on kubelet
    WARN: 4.2.6 Protect kernel defaults should be set
    
    Total: PASS=12, FAIL=5, WARN=8
  critical-findings: |
    1. API server anonymous auth enabled (1.2.1)
    2. Kubelet anonymous auth enabled (4.2.1)
    3. Audit logging not configured (1.2.6)
    4. Profiling enabled on API server (1.2.21)
    5. AlwaysPullImages admission plugin missing (1.2.11)
EOF
```

### Step 4: Create the remediation plan ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cis-remediation-plan
  namespace: lab-1-4
data:
  remediation.md: |
    # CIS Benchmark Remediation Plan
    
    ## Finding 1: API Server Anonymous Auth (1.2.1)
    **Risk**: Unauthenticated requests allowed to API server
    **Fix**: Add --anonymous-auth=false to kube-apiserver manifest
    **File**: /etc/kubernetes/manifests/kube-apiserver.yaml
    
    ## Finding 2: Kubelet Anonymous Auth (4.2.1)
    **Risk**: Unauthenticated requests allowed to kubelet
    **Fix**: Set authentication.anonymous.enabled: false in kubelet config
    **File**: /var/lib/kubelet/config.yaml
    
    ## Finding 3: Audit Logging Not Configured (1.2.6)
    **Risk**: No audit trail for API server requests
    **Fix**: Add --audit-log-path and --audit-policy-file to kube-apiserver
    **File**: /etc/kubernetes/manifests/kube-apiserver.yaml
    
    ## Finding 4: Profiling Enabled (1.2.21)
    **Risk**: Profiling endpoint exposes system information
    **Fix**: Add --profiling=false to kube-apiserver manifest
    
    ## Finding 5: AlwaysPullImages Missing (1.2.11)
    **Risk**: Cached images may be used without re-authentication
    **Fix**: Add AlwaysPullImages to --enable-admission-plugins
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

- **CIS Benchmark**: Center for Internet Security hardening guidelines for Kubernetes
- **kube-bench**: Open-source tool that checks Kubernetes against CIS benchmarks
- **PASS/FAIL/WARN**: kube-bench result categories — FAIL items must be fixed, WARN are recommendations
- **Control plane hardening**: Securing kube-apiserver, etcd, kube-scheduler, kube-controller-manager
- **Node hardening**: Securing kubelet configuration and worker node settings

## Additional Resources

- [kube-bench GitHub](https://github.com/aquasecurity/kube-bench)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Kubernetes Security Hardening Guide](https://kubernetes.io/docs/concepts/security/)
