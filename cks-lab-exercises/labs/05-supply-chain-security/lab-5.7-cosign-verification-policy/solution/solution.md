# Solution: Lab 5.7 - Cosign Verification with Kyverno verifyImages

## Overview

This solution demonstrates how to enforce image signature verification using Kyverno's `verifyImages` rule with Cosign.

## Step-by-Step Solution

### Step 1: Set up the environment

```bash
./setup.sh
```

### Step 2: Generate a Cosign key pair

```bash
# Generate key pair - creates cosign.key (private) and cosign.pub (public)
cosign generate-key-pair

# You'll be prompted for a password (can be empty for lab purposes)
# Output:
# Private key written to cosign.key
# Public key written to cosign.pub
```

### Step 3: Store the public key in a ConfigMap

```bash
kubectl create configmap cosign-public-key \
  --from-file=cosign.pub=./cosign.pub \
  -n lab-5-7
```

### Step 4: Create the Kyverno ClusterPolicy with verifyImages

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
$(cat cosign.pub | sed 's/^/              /')
EOF
```

### Step 5: Create the audit policy

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
$(cat cosign.pub | sed 's/^/              /')
EOF
```

### Step 6: Create the verified-app deployment

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

## Signing an Image with Cosign

```bash
# Sign an image (requires registry access)
cosign sign --key cosign.key myregistry.io/myimage:v1.0

# Verify a signature
cosign verify --key cosign.pub myregistry.io/myimage:v1.0

# Sign with keyless (Sigstore/Fulcio)
COSIGN_EXPERIMENTAL=1 cosign sign myregistry.io/myimage:v1.0
```

## Kyverno verifyImages Rule Structure

```yaml
verifyImages:
- imageReferences:          # Which images to verify
  - "registry.io/org/*"
  required: true            # Block if no signature found
  mutateDigest: true        # Replace tag with digest
  verifyDigest: true        # Verify digest hasn't changed
  attestors:                # Who is trusted to sign
  - count: 1                # At least 1 attestor must match
    entries:
    - keys:
        publicKeys: |-      # Static key verification
          -----BEGIN PUBLIC KEY-----
          ...
          -----END PUBLIC KEY-----
    - keyless:              # Keyless (OIDC) verification
        subject: "https://github.com/org/repo/.github/workflows/build.yml@refs/heads/main"
        issuer: "https://token.actions.githubusercontent.com"
```

## CKS Exam Tips

1. **verifyImages vs validate**: `verifyImages` is specifically for image signature verification
2. **Enforce vs Audit**: `Enforce` blocks, `Audit` only logs violations
3. **background: false**: Required for verifyImages to work at admission time
4. **Key storage**: Public keys can be stored in ConfigMaps or referenced directly in the policy

## Cleanup

```bash
./cleanup.sh
```
