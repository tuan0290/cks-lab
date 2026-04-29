# Lab 2.6: Admission Controllers Configuration

## Metadata

- **Domain**: 2 - Cluster Hardening
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand the role of admission controllers in Kubernetes security
- Enable and configure key security admission controllers
- Test admission controller behavior with compliant and non-compliant resources
- Understand the difference between validating and mutating admission controllers

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Access to kube-apiserver manifest (control plane node)

## Scenario

Your cluster's API server is missing several important admission controllers. You need to verify which admission controllers are enabled, document the security-relevant ones, and test their behavior.

## Requirements

1. Create namespace `lab-2-6`
2. Create a ConfigMap `admission-controllers-config` listing enabled and recommended admission controllers
3. Create a ConfigMap `admission-test-results` documenting test results for key controllers
4. Verify that `PodSecurity` admission controller is active by testing namespace labels

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Check enabled admission controllers

```bash
# Check kube-apiserver flags (on control plane node)
# cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep admission

# Or check via API
kubectl get --raw /api/v1 | python3 -c "import sys,json; print('API accessible')"
```

### Step 3: Create the admission controllers config

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: admission-controllers-config
  namespace: lab-2-6
data:
  enabled-controllers: |
    # Security-relevant admission controllers (recommended for CKS)
    
    ## Validating Controllers
    - PodSecurity: Enforces Pod Security Standards
    - NodeRestriction: Limits kubelet permissions
    - DenyServiceExternalIPs: Blocks external IPs on Services
    
    ## Mutating Controllers
    - DefaultStorageClass: Adds default storage class
    - MutatingAdmissionWebhook: Custom mutation webhooks
    
    ## Both
    - ValidatingAdmissionWebhook: Custom validation webhooks
    - ResourceQuota: Enforces resource quotas
    - LimitRanger: Enforces LimitRange policies
    
    ## Recommended to DISABLE
    - AlwaysAdmit: Allows all requests (security risk)
    - AlwaysPullImages: Forces image pulls (recommended to ENABLE)
  
  api-server-flags: |
    # Recommended kube-apiserver admission plugin flags:
    --enable-admission-plugins=NodeRestriction,PodSecurity,ResourceQuota,LimitRanger
    --disable-admission-plugins=AlwaysAdmit
EOF
```

### Step 4: Test PodSecurity admission controller

```bash
# Create a namespace with restricted PSS
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: pss-test
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
EOF

# Try to create a privileged pod (should be blocked)
cat <<EOF | kubectl apply -f - 2>&1 || echo "Pod correctly blocked by PodSecurity"
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: pss-test
spec:
  containers:
  - name: test
    image: nginx:1.25
    securityContext:
      privileged: true
EOF
```

### Step 5: Create test results ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: admission-test-results
  namespace: lab-2-6
data:
  results.md: |
    # Admission Controller Test Results
    
    ## PodSecurity Test
    - Namespace: pss-test with enforce: restricted
    - Test: Create privileged pod
    - Result: BLOCKED (expected)
    
    ## NodeRestriction Test
    - Prevents kubelets from modifying nodes/pods outside their scope
    - Cannot be tested without kubelet credentials
    
    ## ResourceQuota Test
    - Enforces resource limits per namespace
    - Test: Create pod exceeding quota
    - Result: BLOCKED when quota exceeded
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

- **Admission controllers**: Plugins that intercept API requests after authentication/authorization
- **Validating vs Mutating**: Validating can reject; Mutating can modify resources
- **PodSecurity**: Replaces deprecated PodSecurityPolicy (PSP)
- **NodeRestriction**: Prevents kubelets from modifying resources outside their node

## Additional Resources

- [Admission Controllers Reference](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
