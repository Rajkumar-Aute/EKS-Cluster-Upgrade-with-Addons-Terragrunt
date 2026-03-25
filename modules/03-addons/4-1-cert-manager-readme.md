# cert-manager is the "CA" (Certificate Authority) of cluster.
Verifying it requires checking three layers: 
1. the Controller (the brain), 
2. the Webhook (the gatekeeper), and 
3. the ClusterIssuer (the logic that talks to Let's Encrypt).

Step-by-step verification playbook:

#### Step 1: Verify the Core Components
Ensure all three cert-manager pods (Controller, Webhook, and CA Injector) are running.

```Bash
kubectl get pods -n cert-manager
```
What to look for: You should see 3 pods in the Running state. If the Webhook pod is not running, you won't be able to create any certificates or issuers.

#### Step 2: Verify the API & CRDs
Cert-manager adds its own custom API groups to Kubernetes. Check if they are registered:

```Bash
kubectl api-resources | grep cert-manager
```
What to look for: You should see a list of resources like certificates, certificaterequests, and issuers. This confirms installCRDs: true worked.

#### Step 3: Verify the ClusterIssuer Status
This is the most critical check. It ensures your letsencrypt-prod issuer is successfully registered with Let's Encrypt.

```Bash
kubectl get clusterissuer letsencrypt-prod
```
What to look for: Under the READY column, it must say True.

If it doesn't say True, check the status details:

```Bash
kubectl describe clusterissuer letsencrypt-prod
```
Look for: A message saying "The ACME account was registered with the ACME server".

#### Step 4: Functional Test (Self-Signed Cert)
To ensure the internal "handshake" works without waiting for a real DNS record, create a temporary self-signed certificate.

1. Create the Issuer:

```Bash
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

```Bash
kubectl get certificate selfsigned-cert
```
What to look for: It should reach READY: True within seconds.

#### Step 5: Check the Let's Encrypt Logs
If your letsencrypt-prod issuer fails, check the logs of the main controller to see why (usually it's a blocked port 80 or a typo in the email).

```Bash
kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager -c cert-manager
```