# Lab 1.7: Node Metadata Protection

## Metadata

- **Domain**: 1 - Cluster Setup
- **Difficulty**: Medium
- **Estimated Time**: 15 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand the risk of cloud instance metadata API access from pods
- Block pod access to the node metadata endpoint using NetworkPolicy
- Understand why metadata API access is a security risk (credential theft)

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- CNI plugin supporting NetworkPolicy

## Scenario

Pods in your cluster can access the cloud provider's instance metadata API (169.254.169.254), which may expose IAM credentials and sensitive configuration. You must block this access using NetworkPolicy to prevent credential theft from compromised pods.

## Requirements

1. Create namespace `lab-1-7`
2. Create a NetworkPolicy `block-metadata` that denies egress to `169.254.169.254/32` on port 80 and 443 for all pods in the namespace
3. Create a pod `test-pod` in the namespace to demonstrate the policy applies

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-1-7`.

2. **Task**: Create a NetworkPolicy named `block-metadata` in namespace `lab-1-7` that:
   - Applies to **all pods** (`podSelector: {}`)
   - Sets `policyTypes: [Egress]`
   - Allows egress to `0.0.0.0/0` **except** `169.254.169.254/32` (the cloud metadata endpoint)
   - Allows egress to `kube-system` namespace on UDP/TCP port `53` for DNS

3. **Task**: Create a Pod named `test-pod` in namespace `lab-1-7` with label `app=test` using image `nginx:1.25`.

4. **Verify**: Run `./verify.sh` — all checks must pass.

> **Why this matters**: The cloud instance metadata API at `169.254.169.254` can expose IAM credentials. A compromised pod could steal node credentials via this endpoint.

## Instructions

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-metadata
  namespace: lab-1-7
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
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

### Step 3: Create a test pod

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: lab-1-7
  labels:
    app: test
spec:
  containers:
  - name: test
    image: nginx:1.25
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
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

- **Instance Metadata API**: Cloud provider endpoint at `169.254.169.254` exposing VM credentials
- **ipBlock with except**: NetworkPolicy can allow a CIDR range but exclude specific IPs
- **SSRF risk**: A compromised pod can use the metadata API to steal IAM credentials

## Additional Resources

- [AWS Instance Metadata](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)
- [NetworkPolicy ipBlock](https://kubernetes.io/docs/concepts/services-networking/network-policies/#behavior-of-ipblock-peering)
