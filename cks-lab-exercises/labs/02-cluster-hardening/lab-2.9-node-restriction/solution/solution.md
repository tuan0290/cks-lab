# Solution: NodeRestriction Admission Controller

Follow Steps 3-5 from the README. Key: label a node as cluster admin and document the restrictions.

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl label node "$NODE" security-zone=production --overwrite
```
