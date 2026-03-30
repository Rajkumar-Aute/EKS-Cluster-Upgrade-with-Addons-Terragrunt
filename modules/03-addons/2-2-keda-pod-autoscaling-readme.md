# KEDA 

steps in order to confirm your KEDA installation is fully functional.

#### Step 1: Core Operator Health Check
First, ensure the KEDA components are running correctly on your manual nodes.

```Bash
kubectl get pods -n keda -o wide
```

What to look for: You should see three pods: keda-operator, keda-metrics-apiserver, and keda-admission-webhooks.

Verification: All pods must be in the Running state. Under the NODE column, verify they are running on your ip-172-31-x-x managed nodes.

#### Step 2: IRSA (IAM Role) Verification
KEDA needs to "assume" an IAM role to talk to AWS services (like SQS or CloudWatch).

```Bash
# Describe the ServiceAccount to ensure the annotation is present
kubectl describe sa keda-operator -n keda

# Get the fresh Pod Name
KEDA_POD=$(kubectl get pods -n keda -l app.kubernetes.io/name=keda-operator -o jsonpath='{.items[0].metadata.name}')

# Check for the 4 Critical AWS Variables
kubectl describe pod $KEDA_POD -n keda | grep -A 12 "Environment"
```

The "Big Four" Success Criteria:
AWS_ROLE_ARN (The IAM Role) — CRITICAL
AWS_WEB_IDENTITY_TOKEN_FILE (The Token) — CRITICAL
AWS_STS_REGIONAL_ENDPOINTS (Set to regional)
AWS_DEFAULT_REGION (e.g., us-east-1)

### Step 3: Metrics API Registration
KEDA acts as an "Extension API Server." It tells Kubernetes how to handle external metrics.

```Bash
kubectl get apiservice | grep v1beta1.external.metrics.k8s.io
```

Success Criteria: The output should show v1beta1.external.metrics.k8s.io with the status Available = True. If this is missing or False, the KEDA metrics server cannot communicate with the Kubernetes HPA (Horizontal Pod Autoscaler).

#### Step 4: Functional Scaling Test (The "Dry Run")
We will create a test deployment and a KEDA ScaledObject that uses a simple "cron" trigger to verify KEDA can actually command the cluster to scale.

1. Create a dummy deployment:

```Bash
kubectl create deployment keda-test-app --image=nginx
```
2. Apply a KEDA ScaledObject (Schedules 5 replicas every minute):
Save this as test-keda.yaml and run kubectl apply -f test-keda.yaml:

```YAML
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cron-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: keda-test-app
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
  - type: cron
    metadata:
      timezone: UTC
      start: 0 * * * * # Start of every hour
      end: 59 * * * * # End of every hour
      desiredReplicas: "5"
```
3. Watch the scaling happen:

```Bash
kubectl get pods -l app=keda-test-app -w
```
Success Criteria: You should see the pod count jump from 1 to 5.

#### Step 5: High-Density Node Check (110 Pods Proof)
Since you are optimizing for pod density, let's verify KEDA isn't blocked by node capacity.

```Bash
# Check if your keda-test-app pods are packing onto one node
kubectl get pods -l app=keda-test-app -o wide

# Check the remaining capacity of that node
kubectl describe node <node-name-from-above> | grep -A 5 "Allocated resources"
```
Verification: Ensure the "Non-terminated Pods" count is increasing beyond the default 29-pod limit without errors.