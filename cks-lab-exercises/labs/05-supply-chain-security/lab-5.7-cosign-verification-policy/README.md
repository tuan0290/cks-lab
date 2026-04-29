# Lab 5.7: Cosign Verification with Kyverno verifyImages

## Metadata
- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives
- Configure Kyverno `verifyImages` rules to enforce image signature verification
- Understand how Cosign integrates with Kyverno admission control
- Create policies that block unsigned images from being deployed
- Test policy enforcement with signed and unsigned images
- Understand keyless signing with Sigstore/Fulcio

## Prerequisites
- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- cosign installed (`https://docs.sigstore.dev/cosign/installation/`)
- Kyverno installed in the cluster

## Scenario

Your organization requires that all container images deployed to production must be cryptographically signed using Cosign. You need to configure Kyverno to automatically verify image signatures at admission time, blocking any unsigned or improperly signed images from being deployed. This ensures that only images that have passed your build pipeline and been signed by authorized parties can run in the cluster.

## Requirements

1. Generate a Cosign key pair for image signing
2. Create a Kyverno `ClusterPolicy` with `verifyImages` rule that enforces signature verification
3. Create a ConfigMap storing the public key for verification
4. Test that unsigned images are blocked by the policy
5. Create a deployment with a properly annotated image reference

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-5-7`.

2. **Task**: Generate a Cosign key pair:
   ```bash
   COSIGN_PASSWORD="" cosign generate-key-pair
   ```

3. **Task**: Store the public key in a ConfigMap named `cosign-public-key` in namespace `lab-5-7`:
   ```bash
   kubectl create configmap cosign-public-key \
     --from-file=cosign.pub=./cosign.pub -n lab-5-7
   ```

4. **Task**: Create a Kyverno `ClusterPolicy` named `verify-image-signatures` in `Audit` mode with a `verifyImages` rule for namespace `lab-5-7` that requires images to be signed with the key from `cosign-public-key`.

5. **Task**: Create a Kyverno `ClusterPolicy` named `audit-image-signatures` in `Audit` mode that checks all images in namespace `lab-5-7` for Cosign signatures.

6. **Task**: Create a Deployment named `verified-app` in namespace `lab-5-7` using image `gcr.io/distroless/static-debian12:nonroot` with annotation `security.cosign/verified: "true"`.

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Generate a Cosign key pair

```bash
# Generate key pair (creates cosign.key and cosign.pub)
cosign generate-key-pair

# View the public key
cat cosign.pub
```

### Step 3: Store the public key in a ConfigMap

```bash
# Store the public key for use in Kyverno policy
kubectl create configmap cosign-public-key \
  --from-file=cosign.pub=./cosign.pub \
  -n lab-5-7 \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 4: Create a Kyverno ClusterPolicy with verifyImages

```bash
# Get the public key content
PUBLIC_KEY=$(cat cosign.pub)

cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
  annotations:
    policies.kyverno.io/title: Verify Image Signatures
    policies.kyverno.io/description: Requires all images to be signed with Cosign.
spec:
  validationFailureAction: Enforce
  background: false
  rules:
  - name: verify-cosign-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-7
    verifyImages:
    - imageReferences:
      - "docker.io/library/*"
      - "gcr.io/*"
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEexamplekeycontenthere==
              -----END PUBLIC KEY-----
EOF
```

### Step 5: Create a policy in Audit mode for testing

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: audit-image-signatures
  annotations:
    policies.kyverno.io/title: Audit Image Signatures
    policies.kyverno.io/description: Audits images for Cosign signatures (non-blocking).
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: check-image-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-7
    verifyImages:
    - imageReferences:
      - "*"
      required: false
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEexamplekeycontenthere==
              -----END PUBLIC KEY-----
EOF
```

### Step 6: Create a deployment that references the verification policy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: verified-app
  namespace: lab-5-7
  annotations:
    security.cosign/verified: "true"
    security.cosign/key-ref: "k8s://lab-5-7/cosign-public-key"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: verified-app
  template:
    metadata:
      labels:
        app: verified-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
      containers:
      - name: app
        image: gcr.io/distroless/static-debian12:nonroot
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        resources:
          limits:
            cpu: "100m"
            memory: "32Mi"
EOF
```

### Step 7: Verify your solution

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

- **verifyImages**: Kyverno rule type specifically for image signature verification
- **Cosign key pair**: `cosign.key` (private, for signing) and `cosign.pub` (public, for verification)
- **Keyless signing**: Uses Sigstore/Fulcio CA instead of static keys (OIDC-based)
- **Attestors**: Define who is trusted to sign images in Kyverno policies
- **validationFailureAction: Enforce**: Blocks non-compliant resources; `Audit` only logs

## Additional Resources

- [Kyverno verifyImages](https://kyverno.io/docs/writing-policies/verify-images/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/)
- [Sigstore Policy Controller](https://docs.sigstore.dev/policy-controller/overview/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
