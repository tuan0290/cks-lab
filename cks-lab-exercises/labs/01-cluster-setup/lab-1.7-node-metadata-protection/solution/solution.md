# Solution: Node Metadata Protection

Apply the NetworkPolicy from Step 2 of the README.

Key: use `ipBlock.cidr: 0.0.0.0/0` with `except: [169.254.169.254/32]` to allow all traffic except the metadata endpoint.

```bash
kubectl describe networkpolicy block-metadata -n lab-1-7
```
