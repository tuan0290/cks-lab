# Solution: Lab 5.9 - Supply Chain Attestation with In-toto and SLSA

## Overview

This solution demonstrates how to work with SLSA provenance attestations and configure Kyverno to verify them at deployment time.

## Step-by-Step Solution

### Step 1: Set up the environment

```bash
./setup.sh
```

### Step 2: Generate a Cosign key pair

```bash
cosign generate-key-pair
# Enter a password (can be empty for lab purposes)
```

### Step 3: Create the SLSA policy configuration

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: slsa-policy-config
  namespace: lab-5-9
data:
  slsa-level: "2"
  required-builder: "https://github.com/actions/runner"
  allowed-build-types: "https://slsa.dev/provenance/v0.2"
  attestation-type: "https://slsa.dev/provenance/v0.2"
  verify-provenance: "true"
EOF
```

### Step 4: Create the in-toto attestation example

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: intoto-attestation-example
  namespace: lab-5-9
data:
  attestation.json: |
    {
      "_type": "https://in-toto.io/Statement/v0.1",
      "predicateType": "https://slsa.dev/provenance/v0.2",
      "subject": [
        {
          "name": "registry.example.com/myapp",
          "digest": {
            "sha256": "abc123def456..."
          }
        }
      ],
      "predicate": {
        "builder": {
          "id": "https://github.com/actions/runner"
        },
        "buildType": "https://slsa.dev/provenance/v0.2",
        "invocation": {
          "configSource": {
            "uri": "git+https://github.com/org/repo@refs/heads/main",
            "digest": {
              "sha1": "abc123"
            },
            "entryPoint": ".github/workflows/build.yml"
          }
        },
        "metadata": {
          "buildStartedOn": "2024-01-01T00:00:00Z",
          "buildFinishedOn": "2024-01-01T00:05:00Z",
          "completeness": {
            "parameters": true,
            "environment": false,
            "materials": true
          },
          "reproducible": false
        },
        "materials": [
          {
            "uri": "git+https://github.com/org/repo",
            "digest": {
              "sha1": "abc123"
            }
          }
        ]
      }
    }
EOF
```

### Step 5: Create the Kyverno attestation verification policy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-slsa-attestation
  annotations:
    policies.kyverno.io/title: Verify SLSA Attestation
    policies.kyverno.io/description: Verifies SLSA provenance attestations for container images.
spec:
  validationFailureAction: Audit
  background: false
  rules:
  - name: check-slsa-provenance
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - lab-5-9
    verifyImages:
    - imageReferences:
      - "registry.example.com/*"
      attestations:
      - predicateType: https://slsa.dev/provenance/v0.2
        attestors:
        - count: 1
          entries:
          - keys:
              publicKeys: |-
$(cat cosign.pub | sed 's/^/                /')
        conditions:
        - all:
          - key: "{{ predicate.builder.id }}"
            operator: Equals
            value: "https://github.com/actions/runner"
EOF
```

### Step 6: Create the attested application deployment

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: attested-app
  namespace: lab-5-9
  annotations:
    security.slsa/level: "2"
    security.slsa/builder: "https://github.com/actions/runner"
    security.slsa/provenance-verified: "true"
    security.cosign/attestation-type: "https://slsa.dev/provenance/v0.2"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: attested-app
  template:
    metadata:
      labels:
        app: attested-app
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

## Creating and Verifying Attestations with Cosign

```bash
# Create an attestation (requires registry access)
cosign attest --key cosign.key \
  --predicate attestation.json \
  --type slsaprovenance \
  myregistry.io/myimage:v1.0

# Verify an attestation
cosign verify-attestation --key cosign.pub \
  --type slsaprovenance \
  myregistry.io/myimage:v1.0

# View attestation content
cosign verify-attestation --key cosign.pub \
  --type slsaprovenance \
  myregistry.io/myimage:v1.0 | jq .
```

## SLSA Levels Explained

| Level | Requirements |
|-------|-------------|
| **SLSA 1** | Build process is documented and generates provenance |
| **SLSA 2** | Build service generates authenticated provenance |
| **SLSA 3** | Build service is hardened, provenance is non-falsifiable |
| **SLSA 4** | Two-party review of all changes |

## Signature vs Attestation

| Aspect | Signature | Attestation |
|--------|-----------|-------------|
| **Purpose** | Proves authenticity | Proves provenance/metadata |
| **Content** | Just the image digest | Rich metadata (builder, materials, etc.) |
| **Use case** | "This image is authentic" | "This image was built by X from Y" |
| **Cosign command** | `cosign sign` | `cosign attest` |

## CKS Exam Tips

1. **SLSA framework**: Know the 4 levels and what each requires
2. **In-toto**: Understand it's a framework for supply chain attestations
3. **Kyverno attestations**: Use `verifyImages.attestations` with `predicateType`
4. **Cosign attest**: Know the difference between `sign` and `attest`

## Cleanup

```bash
./cleanup.sh
```
