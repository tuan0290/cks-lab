# Lab 1.6: NetworkPolicy Egress Control

## Metadata

- **Domain**: 1 - Cluster Setup
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Implement egress NetworkPolicy to restrict outbound traffic from pods
- Combine ingress and egress rules in a single NetworkPolicy
- Understand default-deny egress and selective allow patterns
- Test NetworkPolicy enforcement with connectivity checks

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- A CNI plugin that supports NetworkPolicy (Calico, Cilium, Weave)

## Scenario

A backend service in your cluster should only be allowed to communicate with a specific database service and the Kubernetes DNS server. All other outbound traffic must be blocked. You need to implement egress NetworkPolicy to enforce this restriction.

## Requirements

1. Create namespace `lab-1-6` with label `env=lab`
2. Deploy a `backend` pod with label `app=backend`
3. Deploy a `database` pod with label `app=database`
4. Create a NetworkPolicy `backend-egress` that:
   - Applies to pods with label `app=backend`
   - Denies all egress by default
   - Allows egress to pods with label `app=database` on port 5432
   - Allows egress to kube-dns on UDP port 53

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create the backend and database pods

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: lab-1-6
  labels:
    app: backend
spec:
  containers:
  - name: backend
    image: nginx:1.25
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
---
apiVersion: v1
kind: Pod
metadata:
  name: database
  namespace: lab-1-6
  labels:
    app: database
spec:
  containers:
  - name: database
    image: nginx:1.25
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF
```

### Step 3: Create the egress NetworkPolicy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: lab-1-6
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
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

- **Egress NetworkPolicy**: Controls outbound traffic from selected pods
- **Default-deny egress**: Specifying `policyTypes: [Egress]` with no egress rules blocks all outbound
- **DNS egress**: Always allow UDP/TCP 53 to kube-system or pods will fail DNS resolution
- **policyTypes**: Must explicitly list `Egress` to apply egress rules

## Additional Resources

- [NetworkPolicy Egress](https://kubernetes.io/docs/concepts/services-networking/network-policies/#egress)
- [NetworkPolicy Recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)
