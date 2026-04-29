# Lab 5.9: Supply Chain Attestation with In-toto and SLSA

## Metadata
- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives
- Understand the SLSA (Supply-chain Levels for Software Artifacts) framework
- Work with in-toto attestations using Cosign
- Create and verify provenance attestations for container images
- Configure Kyverno to verify attestations before deployment
- Understand the difference between signatures and attestations

## Prerequisites
- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- cosign installed (`https://docs.sigstore.dev/cosign/installation/`)
- Basic understanding of supply chain security concepts

## Scenario

Your organization is implementing SLSA Level 2 compliance for its container build pipeline. This requires that all deployed images have verifiable provenance attestations proving they were built by your authorized CI/CD system. You need to configure Kyverno to verify these attestations at deployment time and create the necessary policies to enforce SLSA compliance.

## Requirements

1. Create a namespace `lab-5-9` for this lab
2. Generate a Cosign key pair for attestation signing
3. Create a ConfigMap `slsa-policy-config` with SLSA compliance settings
4. Create a Kyverno ClusterPolicy `verify-slsa-attestation` that checks for build provenance
5. Create a Deployment `attested-app` with SLSA compliance annotations
6. Create a ConfigMap demonstrating an in-toto attestation structure

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-5-9`.

2. **Task**: Generate a Cosign key pair for attestation signing:
   ```bash
   COSIGN_PASSWORD="" cosign generate-key-pair
   ```

3. **Task**: Create a ConfigMap named `slsa-policy-config` in namespace `lab-5-9` with:
   - `slsa-level: "2"`
   - `required-builder: https://github.com/actions/runner`
   - `attestation-type: https://slsa.dev/provenance/v0.2`
   - `verify-provenance: "true"`

4. **Task**: Create a ConfigMap named `intoto-attestation-example` in namespace `lab-5-9` with an `attestation.json` key containing a valid in-toto statement structure with `_type`, `predicateType`, `subject`, and `predicate` fields.

5. **Task**: Create a Kyverno ClusterPolicy named `verify-slsa-attestation` in Audit mode with a `verifyImages` rule that checks for SLSA provenance attestations in namespace `lab-5-9`.

6. **Task**: Create a Deployment named `attested-app` in namespace `lab-5-9` using image `gcr.io/distroless/static-debian12:nonroot` with annotations:
   - `security.slsa/level: "2"`
   - `security.cosign/attestation-type: https://slsa.dev/provenance/v0.2`

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Generate a Cosign key pair for attestations

```bash
cosign generate-key-pair
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

### Step 4: Create an in-toto attestation example

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

### Step 5: Create a Kyverno policy to verify attestations

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
                -----BEGIN PUBLIC KEY-----
                MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEexamplekeycontenthere==
                -----END PUBLIC KEY-----
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

- **SLSA**: Supply-chain Levels for Software Artifacts — a security framework for supply chain integrity
- **In-toto**: A framework for securing the software supply chain through attestations
- **Provenance**: Metadata about how an artifact was produced (who built it, when, from what source)
- **Attestation**: A signed statement about an artifact (different from a signature — it carries metadata)
- **SLSA Levels**: 1 (basic provenance) → 2 (hosted build) → 3 (hardened build) → 4 (two-party review)

## Additional Resources

- [SLSA Framework](https://slsa.dev/)
- [In-toto Specification](https://in-toto.io/)
- [Cosign Attestations](https://docs.sigstore.dev/cosign/attestation/)
- [Kyverno verifyImages Attestations](https://kyverno.io/docs/writing-policies/verify-images/sigstore/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
