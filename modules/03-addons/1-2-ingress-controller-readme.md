# Verify the NGINX Ingress Controller
## need to ensure that the AWS Load Balancer Controller has successfully provisioned a Physical Network Load Balancer (NLB) and that NGINX is ready to accept traffic.

### step-by-step validation guide.

#### Step 1: Verify Kubernetes Resources
First, ensure the pods are running and the Service has received an external address from AWS.

Check Pod Status:

```Bash
kubectl get pods -n ingress-nginx
```
You should see 2 replicas running (as per your replicaCount: 2).

Check the LoadBalancer Service:

```Bash
kubectl get svc -n ingress-nginx
```
Under the EXTERNAL-IP column, you should see a long AWS hostname (e.g., k8s-ingressn-ingressn-...elb.us-east-1.amazonaws.com). If it <pending>, wait for 2 minutes.

#### Step 2: Verify AWS Infrastructure
Since you are using the external load balancer type, the AWS Load Balancer Controller does the heavy lifting.

Check Controller Logs for Errors:
If the Service has no IP, the error is usually in the LBC logs:

```Bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail 50
```
Look for: successfully created target group or AccessDenied.

Verify via AWS CLI:
Confirm the NLB exists in your AWS account:

```Bash
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(DNSName, 'ingress-nginx')].LoadBalancerName"
```

#### Step 3: Functional Traffic Test
The best way to verify an Ingress Controller is to send a request to it. Even without an application deployed, NGINX should return a 404 Not Found (which is a good sign—it means the server is alive).

Get the NLB URL:

```Bash
export NLB_URL=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $NLB_URL

curl -I http://$NLB_URL
```
Success: You should get HTTP/1.1 404 Not Found from a server header named nginx.

#### Step 4: End-to-End Ingress Test
Now, let's see if NGINX can route traffic to a real app using a fake host.

Create a Sample App & Ingress:
Save as nginx-test.yaml:

```YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-app
spec:
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo
        args: ["-text", "NGINX is working!"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: echo-service
spec:
  ports:
  - port: 80
    targetPort: 5678
  selector:
    app: echo
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: test.eks.devsecopsguru.in
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: echo-service
            port:
              number: 80
```

```Bash
kubectl apply -f nginx-test.yaml
# Test using the host header (simulates a DNS entry)
curl -H "Host: test.eks.devsecopsguru.in" http://$NLB_URL
```
Success: You should see the response: __NGINX is working!__