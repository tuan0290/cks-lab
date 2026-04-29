# Lab 1.5: Ingress TLS Configuration

## Metadata

- **Domain**: 1 - Cluster Setup
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Create TLS certificates and store them as Kubernetes Secrets
- Configure an Ingress resource with TLS termination
- Enforce HTTPS-only access by redirecting HTTP to HTTPS
- Understand TLS secret format and Ingress TLS spec

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- An Ingress controller installed (nginx-ingress or similar)
- openssl available

## Scenario

Your team needs to expose a web application securely over HTTPS. You must create a self-signed TLS certificate, store it as a Kubernetes Secret, and configure an Ingress resource to terminate TLS. The application must only be accessible via HTTPS.

## Requirements

1. Create namespace `lab-1-5`
2. Create a TLS Secret `app-tls-secret` in namespace `lab-1-5` using a self-signed certificate for `app.example.com`
3. Deploy a simple application `web-app` (nginx) in namespace `lab-1-5`
4. Create a Service `web-app-svc` exposing the deployment on port 80
5. Create an Ingress `web-app-ingress` with TLS configured using `app-tls-secret`

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-1-5`.

2. **Task**: Generate a self-signed TLS certificate for hostname `app.example.com` with validity of 365 days:
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /tmp/tls.key -out /tmp/tls.crt \
     -subj "/CN=app.example.com/O=lab"
   ```

3. **Task**: Create a TLS Secret named `app-tls-secret` in namespace `lab-1-5` using the generated certificate.
   - The Secret type must be `kubernetes.io/tls`

4. **Task**: Create a Deployment named `web-app` in namespace `lab-1-5` using image `nginx:1.25`, and a Service named `web-app-svc` exposing it on port 80.

5. **Task**: Create an Ingress named `web-app-ingress` in namespace `lab-1-5` that:
   - Terminates TLS using Secret `app-tls-secret`
   - Routes traffic for host `app.example.com` to Service `web-app-svc` on port 80
   - Forces HTTPS redirect (annotation: `nginx.ingress.kubernetes.io/ssl-redirect: "true"`)

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

```bash
# Generate private key and self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/CN=app.example.com/O=lab"

# Verify the certificate
openssl x509 -in /tmp/tls.crt -text -noout | grep -E "Subject:|DNS:"
```

### Step 3: Create the TLS Secret

```bash
kubectl create secret tls app-tls-secret \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  -n lab-1-5 \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify the secret
kubectl get secret app-tls-secret -n lab-1-5 -o jsonpath='{.type}'
```

### Step 4: Deploy the web application

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: lab-1-5
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "100m"
            memory: "64Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
  namespace: lab-1-5
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
EOF
```

### Step 5: Create the Ingress with TLS

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
  namespace: lab-1-5
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls-secret
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-svc
            port:
              number: 80
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

- **TLS Secret**: Type `kubernetes.io/tls` with `tls.crt` and `tls.key` data fields
- **Ingress TLS**: The `spec.tls` section links a hostname to a TLS secret
- **SSL redirect**: Annotation to force HTTP → HTTPS redirect at the Ingress controller
- **Self-signed vs CA-signed**: Self-signed certs work for labs; production needs a CA or cert-manager

## Additional Resources

- [Kubernetes Ingress TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)
- [cert-manager](https://cert-manager.io/)
- [nginx-ingress TLS](https://kubernetes.github.io/ingress-nginx/user-guide/tls/)
