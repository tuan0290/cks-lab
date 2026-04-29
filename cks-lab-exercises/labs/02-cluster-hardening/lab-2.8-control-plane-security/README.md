# Lab 2.8: Control Plane Security Hardening

## Metadata

- **Domain**: 2 - Cluster Hardening
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Audit kube-apiserver security flags for hardening
- Understand etcd security configuration
- Verify kube-scheduler and kube-controller-manager security settings
- Document control plane security configuration

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

A security audit has flagged several control plane components as insufficiently hardened. You need to audit the current configuration, document findings, and create a remediation plan for the kube-apiserver, etcd, kube-scheduler, and kube-controller-manager.

## Requirements

1. Create namespace `lab-2-8`
2. Create a ConfigMap `apiserver-security-config` documenting recommended API server flags
3. Create a ConfigMap `etcd-security-config` documenting etcd security settings
4. Create a ConfigMap `control-plane-audit` with the audit findings

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Audit API server configuration

```bash
# Check current API server flags (on control plane node)
# cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -E "\-\-"

# Check via kubectl
kubectl get pod kube-apiserver-$(hostname) -n kube-system -o yaml 2>/dev/null | grep -A200 "command:" | head -50 || echo "Cannot access kube-apiserver pod directly"
```

### Step 3: Create the API server security config

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: apiserver-security-config
  namespace: lab-2-8
data:
  recommended-flags.yaml: |
    # Recommended kube-apiserver security flags
    
    ## Authentication
    --anonymous-auth=false
    --oidc-issuer-url=<issuer>  # If using OIDC
    
    ## Authorization
    --authorization-mode=Node,RBAC
    
    ## Admission
    --enable-admission-plugins=NodeRestriction,PodSecurity
    
    ## Audit
    --audit-log-path=/var/log/kubernetes/audit.log
    --audit-log-maxage=30
    --audit-log-maxbackup=10
    --audit-log-maxsize=100
    --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    
    ## TLS
    --tls-min-version=VersionTLS12
    --tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    
    ## Other
    --profiling=false
    --request-timeout=300s
    --service-account-lookup=true
EOF
```

### Step 4: Create etcd security config

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: etcd-security-config
  namespace: lab-2-8
data:
  etcd-security.md: |
    # etcd Security Configuration
    
    ## TLS Configuration
    --cert-file=/etc/kubernetes/pki/etcd/server.crt
    --key-file=/etc/kubernetes/pki/etcd/server.key
    --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    --client-cert-auth=true
    --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
    --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
    --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    --peer-client-cert-auth=true
    
    ## Access Control
    - etcd should only be accessible from the API server
    - Use NetworkPolicy or firewall rules to restrict access to etcd port (2379)
    - etcd data directory should have restricted permissions (700)
    
    ## Backup
    - Regular etcd snapshots: etcdctl snapshot save
    - Encrypt etcd data at rest using EncryptionConfiguration
EOF
```

### Step 5: Create audit findings

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: control-plane-audit
  namespace: lab-2-8
data:
  findings.md: |
    # Control Plane Security Audit
    Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    ## kube-apiserver
    FINDING: Check --anonymous-auth flag (should be false)
    FINDING: Verify --authorization-mode includes RBAC and Node
    FINDING: Confirm audit logging is configured
    FINDING: Verify --profiling=false
    
    ## etcd
    FINDING: Verify TLS is enabled for client and peer communication
    FINDING: Confirm --client-cert-auth=true
    FINDING: Check etcd data directory permissions
    
    ## kube-scheduler
    FINDING: Verify --profiling=false
    FINDING: Confirm --bind-address=127.0.0.1
    
    ## kube-controller-manager
    FINDING: Verify --profiling=false
    FINDING: Confirm --use-service-account-credentials=true
    FINDING: Check --bind-address=127.0.0.1
EOF
```

### Step 6: Verify your solution

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

- **--anonymous-auth=false**: Disables unauthenticated API access
- **--authorization-mode=Node,RBAC**: Enables node and RBAC authorization
- **--profiling=false**: Disables profiling endpoint that exposes system info
- **etcd TLS**: All etcd communication should be encrypted

## Additional Resources

- [API Server Security](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
- [etcd Security](https://etcd.io/docs/v3.5/op-guide/security/)
