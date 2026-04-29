# Solution: Ingress TLS Configuration

## Step 1: Generate TLS certificate

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=app.example.com/O=lab"
```

## Step 2: Create TLS Secret

```bash
kubectl create secret tls app-tls-secret \
  --cert=/tmp/tls.crt --key=/tmp/tls.key \
  -n lab-1-5
```

## Step 3: Deploy app and create Ingress

Apply the Deployment, Service, and Ingress manifests from the README.

## Verification

```bash
# Check secret type
kubectl get secret app-tls-secret -n lab-1-5 -o jsonpath='{.type}'
# Expected: kubernetes.io/tls

# Check Ingress TLS
kubectl get ingress web-app-ingress -n lab-1-5 -o yaml | grep -A5 tls:
```

## Common Mistakes

- Secret must be type `kubernetes.io/tls` — use `kubectl create secret tls`, not generic
- The `secretName` in Ingress `spec.tls` must exactly match the Secret name
- The hostname in `spec.tls[].hosts` must match the `spec.rules[].host`
