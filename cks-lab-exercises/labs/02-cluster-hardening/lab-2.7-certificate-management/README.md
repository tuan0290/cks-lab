# Lab 2.7: Certificate Management and Rotation

## Metadata

- **Domain**: 2 - Cluster Hardening
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Inspect Kubernetes cluster certificates and their expiration dates
- Understand the certificate hierarchy in a kubeadm cluster
- Use kubeadm to check and renew certificates
- Create a CertificateSigningRequest (CSR) for a new user

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

Your cluster certificates are approaching expiration. You need to audit all certificate expiration dates, document the renewal procedure, and create a new user certificate using the Kubernetes CSR API.

## Requirements

1. Create namespace `lab-2-7`
2. Create a ConfigMap `cert-expiry-report` documenting certificate expiration dates
3. Create a CertificateSigningRequest `dev-user-csr` for a developer user
4. Approve the CSR and create a ConfigMap `csr-procedure` documenting the process

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-2-7`.

2. **Task**: Generate a private key and CSR for user `dev-user` in group `developers`:
   ```bash
   openssl genrsa -out /tmp/dev-user.key 2048
   openssl req -new -key /tmp/dev-user.key -out /tmp/dev-user.csr \
     -subj "/CN=dev-user/O=developers"
   ```

3. **Task**: Create a Kubernetes `CertificateSigningRequest` named `dev-user-csr` with:
   - `signerName: kubernetes.io/kube-apiserver-client`
   - `expirationSeconds: 86400`
   - `usages: [client auth]`
   - The base64-encoded content of `/tmp/dev-user.csr`

4. **Task**: Approve the CSR and verify it shows `Approved,Issued`:
   ```bash
   kubectl certificate approve dev-user-csr
   kubectl get csr dev-user-csr
   ```

5. **Task**: Retrieve the signed certificate:
   ```bash
   kubectl get csr dev-user-csr -o jsonpath='{.status.certificate}' | base64 -d > /tmp/dev-user.crt
   openssl x509 -in /tmp/dev-user.crt -noout -subject -dates
   ```

6. **Task**: Create ConfigMaps `cert-expiry-report` and `csr-procedure` in namespace `lab-2-7`.

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Check certificate expiration (on control plane)

```bash
# Check all cluster certificates (requires control plane access)
# kubeadm certs check-expiration

# Check the API server certificate
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates 2>/dev/null || echo "No direct access to PKI (normal for non-control-plane)"

# Check via kubeconfig
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d | openssl x509 -noout -dates 2>/dev/null || echo "Cannot decode cert"
```

### Step 3: Generate a CSR for a new developer user

```bash
# Generate private key
openssl genrsa -out /tmp/dev-user.key 2048

# Generate CSR
openssl req -new -key /tmp/dev-user.key \
  -out /tmp/dev-user.csr \
  -subj "/CN=dev-user/O=developers"

# Encode CSR in base64
CSR_BASE64=$(cat /tmp/dev-user.csr | base64 | tr -d '\n')

# Create Kubernetes CSR object
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-user-csr
spec:
  request: $CSR_BASE64
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF
```

### Step 4: Approve the CSR

```bash
kubectl certificate approve dev-user-csr

# Retrieve the signed certificate
kubectl get csr dev-user-csr -o jsonpath='{.status.certificate}' | base64 -d > /tmp/dev-user.crt

# Verify the certificate
openssl x509 -in /tmp/dev-user.crt -noout -subject -dates
```

### Step 5: Create documentation ConfigMaps

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cert-expiry-report
  namespace: lab-2-7
data:
  report.md: |
    # Certificate Expiry Report
    Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    ## Cluster Certificates (kubeadm)
    - apiserver.crt: Check with: kubeadm certs check-expiration
    - apiserver-kubelet-client.crt: Used for kubelet communication
    - front-proxy-client.crt: Used for aggregation layer
    - etcd/server.crt: etcd server certificate
    
    ## Renewal Command
    kubeadm certs renew all
    
    ## Auto-renewal
    kubelet client certificates auto-rotate when RotateKubeletClientCertificate=true
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: csr-procedure
  namespace: lab-2-7
data:
  procedure.md: |
    # CSR Procedure for New Users
    
    1. Generate private key: openssl genrsa -out user.key 2048
    2. Generate CSR: openssl req -new -key user.key -out user.csr -subj "/CN=username/O=group"
    3. Create K8s CSR: kubectl apply -f csr.yaml
    4. Approve: kubectl certificate approve <csr-name>
    5. Retrieve cert: kubectl get csr <name> -o jsonpath='{.status.certificate}' | base64 -d > user.crt
    6. Create kubeconfig: kubectl config set-credentials user --client-key=user.key --client-certificate=user.crt
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

- **CertificateSigningRequest**: Kubernetes API object for requesting signed certificates
- **signerName**: `kubernetes.io/kube-apiserver-client` for user client certs
- **Certificate rotation**: kubeadm can renew all certificates with `kubeadm certs renew all`
- **Auto-rotation**: Kubelet client certs auto-rotate before expiry

## Additional Resources

- [Certificate Management](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
- [kubeadm certs](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-certs/)
