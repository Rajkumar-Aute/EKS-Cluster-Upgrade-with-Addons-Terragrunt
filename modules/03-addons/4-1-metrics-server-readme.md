# Verify Metrics Server
Step-by-step validation

#### Step 1: Verify the Pod is Running
First, ensure the Helm chart successfully spun up the pod and it isn't crashing.

```Bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server
```
What to look for: The status should be Running and 1/1 ready.

#### Step 2: Verify the API Registration
The Metrics Server doesn't just run as a pod; it extends the core Kubernetes API. We need to make sure the control plane has successfully registered this extension.

```Bash
kubectl get apiservice v1beta1.metrics.k8s.io
```
What to look for: Look at the AVAILABLE column. It must say True. If it says False, the API server cannot communicate with your metrics-server pod (usually a network policy or security group issue).

#### Step 3: The Ultimate Test (Fetch Metrics)
Once the API is registered and a minute has passed, test the core functionality.

Check Node Metrics:

```Bash
kubectl top nodes
```
What to look for: You should see a list of your EC2 instances with their CPU (in millicores) and Memory (in Mi or Gi) usage.

Check Pod Metrics:

```Bash
kubectl top pods -A
```
What to look for: This will list the resource usage for every running pod across all namespaces.

## Troubleshooting (If kubectl top fails)
If you get an error like Error from server (ServiceUnavailable): the server is currently unable to handle the request, it means the Metrics Server is running but failing to scrape the Kubelets.

Run this command to see exactly why it's failing:

```Bash
kubectl logs -n kube-system -l app.kubernetes.io/name=metrics-server
```
Look for lines containing Failed to scrape node. If you see certificate errors, your --kubelet-insecure-tls flag wasn't applied correctly. If you see connection timeouts, your EKS Node Security Group is blocking port 4443 from the control plane.