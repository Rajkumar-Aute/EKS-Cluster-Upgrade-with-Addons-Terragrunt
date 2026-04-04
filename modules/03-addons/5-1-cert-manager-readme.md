# cert-manager is the "CA" (Certificate Authority) of cluster

Verifying it requires checking three layers:

1. the Controller (the brain),
2. the Webhook (the gatekeeper), and
3. the ClusterIssuer (the logic that talks to Let's Encrypt).

Step-by-step verification playbook:

## Step 1: Verify the Core Components

1. Ensure all three cert-manager pods (Controller, Webhook, and CA Injector) are running.

```
kubectl get pods -n cert-manager
```
What to look for: You should see 3 pods in the Running state. If the Webhook pod is not running, you won't be able to create any certificates or issuers.

## Step 2: Verify the API & CRDs
1. Cert-manager adds its own custom API groups to Kubernetes. Check if they are registered:

```
kubectl api-resources | grep cert-manager
```
What to look for: You should see a list of resources like certificates, certificaterequests, and issuers. This confirms installCRDs: true worked.

## Step 3: Verify the ClusterIssuer Status

1. This is the most critical check. It ensures your letsencrypt-prod issuer is successfully registered with Let's Encrypt.

```
kubectl get clusterissuer letsencrypt-prod
```
What to look for: Under the READY column, it must say True.

2. If it doesn't say True, check the status details:
```
kubectl describe clusterissuer letsencrypt-prod
```
Look for: A message saying "The ACME account was registered with the ACME server".

## Step 4: Functional Test (Self-Signed Cert)
To ensure the internal "handshake" works without waiting for a real DNS record, create a temporary self-signed certificate.

1. Create the Issuer:
```
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: default
spec:
  selfSigned: {}
---

apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: default
spec:
  dnsNames:
    - example.com
  secretName: selfsigned-cert-tls
  issuerRef:
    name: test-selfsigned
EOF
```

2. Verify the Certificate:
```
kubectl get certificate selfsigned-cert
```
What to look for: It should reach READY: True within seconds.

## Step 5: Check the Let's Encrypt Logs

1. If your letsencrypt-prod issuer fails, check the logs of the main controller to see why (usually it's a blocked port 80 or a typo in the email).
```
kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager -c cert-manager
```
