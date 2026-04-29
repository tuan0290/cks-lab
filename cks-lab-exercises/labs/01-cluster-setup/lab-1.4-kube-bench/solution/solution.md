# Solution: CIS Benchmark with kube-bench

## Step 1: Run setup

```bash
./setup.sh
```

## Step 2: Run kube-bench Job

Apply the kube-bench Job manifest from the README. Wait for it to complete:

```bash
kubectl wait --for=condition=complete job/kube-bench -n lab-1-4 --timeout=120s
kubectl logs job/kube-bench -n lab-1-4
```

## Step 3: Create ConfigMaps

Apply both ConfigMaps from the README instructions (Steps 3 and 4).

## Key Remediation Commands

```bash
# View API server manifest
cat /etc/kubernetes/manifests/kube-apiserver.yaml

# Add --anonymous-auth=false to kube-apiserver
# Edit /etc/kubernetes/manifests/kube-apiserver.yaml and add:
# - --anonymous-auth=false

# View kubelet config
cat /var/lib/kubelet/config.yaml

# Disable anonymous auth on kubelet
# Edit /var/lib/kubelet/config.yaml:
# authentication:
#   anonymous:
#     enabled: false
```

## Common Mistakes

- kube-bench Job needs hostPID and access to host paths — it must run on a control-plane node
- Some findings are informational (WARN) and may not apply to all environments
- After remediating API server flags, the static pod will restart automatically
