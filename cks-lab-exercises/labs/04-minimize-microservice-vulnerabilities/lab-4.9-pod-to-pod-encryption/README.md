# Lab 4.9: Pod-to-Pod Encryption with mTLS

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Understand mutual TLS (mTLS) for pod-to-pod communication
- Configure Istio or cert-manager for mTLS
- Verify encrypted communication between pods
- Understand service mesh security concepts

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

Your microservices need encrypted communication between pods. You need to implement mTLS using Kubernetes-native tools and document the approach.

## Requirements

1. Create namespace `lab-4-9` with Istio injection label (or document the approach)
2. Create a ConfigMap `mtls-config` documenting mTLS configuration approaches
3. Create a Secret `service-tls` with a self-signed certificate for service communication
4. Create a Pod `tls-server` that uses the TLS secret

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-4-9`.

2. **Task**: Generate a self-signed TLS certificate for `tls-server.lab-4-9.svc.cluster.local`:
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /tmp/service.key -out /tmp/service.crt \
     -subj "/CN=tls-server.lab-4-9.svc.cluster.local"
   ```

3. **Task**: Create a TLS Secret named `service-tls` in namespace `lab-4-9` from the generated certificate.

4. **Task**: Create a Pod named `tls-server` in namespace `lab-4-9` that mounts the `service-tls` secret as a volume at `/etc/tls` with `defaultMode: 0400`.

5. **Task**: Create a ConfigMap named `mtls-config` in namespace `lab-4-9` documenting 3 approaches to pod-to-pod encryption:
   - Istio service mesh with `PeerAuthentication: STRICT`
   - cert-manager with manual TLS
   - Cilium with IPsec/WireGuard

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: lab-4-9
  labels:
    istio-injection: enabled
EOF
```

### Step 3: Generate TLS certificate for service

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/service.key -out /tmp/service.crt \
  -subj "/CN=tls-server.lab-4-9.svc.cluster.local"

kubectl create secret tls service-tls \
  --cert=/tmp/service.crt --key=/tmp/service.key \
  -n lab-4-9 --dry-run=client -o yaml | kubectl apply -f -
```

### Step 4: Create the TLS server pod

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tls-server
  namespace: lab-4-9
  labels:
    app: tls-server
spec:
  containers:
  - name: server
    image: nginx:1.25
    volumeMounts:
    - name: tls-certs
      mountPath: /etc/tls
      readOnly: true
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
  volumes:
  - name: tls-certs
    secret:
      secretName: service-tls
      defaultMode: 0400
EOF
```

### Step 5: Create mTLS documentation

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mtls-config
  namespace: lab-4-9
data:
  mtls-approaches.md: |
    # Pod-to-Pod Encryption Approaches
    
    ## 1. Istio Service Mesh (Recommended)
    - Automatic mTLS between all pods
    - Enable: kubectl label namespace <ns> istio-injection=enabled
    - PeerAuthentication: enforce STRICT mTLS
    
    ## 2. cert-manager + manual TLS
    - Issue certificates via cert-manager
    - Mount certs as volumes in pods
    - Application handles TLS termination
    
    ## 3. Cilium Network Encryption
    - Transparent encryption at network layer
    - IPsec or WireGuard
    - No application changes needed
    
    ## Istio PeerAuthentication Example
    apiVersion: security.istio.io/v1beta1
    kind: PeerAuthentication
    metadata:
      name: default
      namespace: lab-4-9
    spec:
      mtls:
        mode: STRICT
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

- **mTLS**: Both client and server authenticate with certificates
- **Istio**: Service mesh that provides automatic mTLS
- **PeerAuthentication**: Istio resource to enforce mTLS mode
- **STRICT mode**: Requires mTLS for all communication

## Additional Resources

- [Istio mTLS](https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication)
- [cert-manager](https://cert-manager.io/)
