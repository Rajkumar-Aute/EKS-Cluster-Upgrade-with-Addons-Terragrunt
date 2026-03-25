# Verifying Karpenter 
Karpenter Manages AWS EC2 infrastructure.  
To verify the Controller, the CRDs (NodePool/EC2NodeClass), and finally, a Scaling Test to see it actually launch a node.

#### Step 1: Verify the Controller & Permissions
Before Karpenter can scale, the controller must be healthy and authorized to talk to AWS.

Check Pod Status:

```Bash
kubectl get pods -n karpenter
```

Verify IAM Role Association:
Ensure the controller is using the correct IAM role for Service Accounts (IRSA).

```Bash
kubectl get sa karpenter -n karpenter -o yaml | grep eks.amazonaws.com/role-arn
```

Check Controller Logs (The Source of Truth):
Look for any "AccessDenied" errors regarding EC2 or SQS.

```Bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
```
Success looks like: webhook server started and found 1 EC2NodeClass.

Step 2: Verify Custom Resources (CRDs)
Since you deployed the EC2NodeClass and NodePool, verify Kubernetes has accepted them.

Check NodePool:

Bash
kubectl get nodepool
Check EC2NodeClass:

Bash
kubectl get ec2nodeclass
Check the status of the EC2NodeClass to ensure it found your subnets and security groups:

Bash
kubectl describe ec2nodeclass default
Look at the Status section. It should list specific Subnet IDs and Security Group IDs that Karpenter discovered using your tags.

Step 3: The "Scale-Up" Functional Test
The only way to validate Karpenter is to create "unschedulable" pods and watch it provision a new node.

Deploy a "Balloon" Deployment:
This deployment asks for a lot of CPU that your existing nodes (likely t3.medium) cannot handle.

Bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 5
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      terminationGracePeriodSeconds: 0
      containers:
        - name: inflate
          image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
          resources:
            requests:
              cpu: "1"
EOF
Watch Karpenter Action:
Open two terminal windows:

Terminal 1 (Logs): kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
Watch for: found provisionable pod(s), launching node.

Terminal 2 (Nodes): kubectl get nodes -w
Watch for a new node appearing with a name like ip-10-0-x-x.ec2.internal.

Step 4: Verify Spot Instance & Consolidation
Since your NodePool specifies Spot instances and Consolidation:

Verify Capacity Type:
Check if the new node is actually a Spot instance:

Bash
kubectl get nodes -l karpenter.sh/capacity-type=spot
Test Scale Down:
Delete the deployment and watch Karpenter terminate the node after the consolidateAfter period (1m).

Bash
kubectl delete deployment inflate
Watch logs for: disrupting node via delete.