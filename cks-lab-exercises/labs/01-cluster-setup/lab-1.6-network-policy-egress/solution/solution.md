# Solution: NetworkPolicy Egress Control

Apply the NetworkPolicy from Step 3 of the README. Key points:
- `policyTypes: [Egress]` enables egress filtering
- Allow egress to `app=database` on TCP 5432
- Allow egress to kube-system on UDP/TCP 53 for DNS

```bash
# Verify NetworkPolicy
kubectl describe networkpolicy backend-egress -n lab-1-6
```
