# EKS cluster deployment using Terragrunt

Terragrunt, the deployment flow is slightly different than standard Terraform.


## Prerequisites & Windows Setup
If you are running this on a Windows machine, you must configure your environment to handle Terraform's deep nested directory structures, or you will encounter Filename too long errors.

Open your Git Bash terminal and run:

```Bash
# Tell Git to ignore the Windows 260-character path limit
git config --global core.longpaths true
```

## Step 1: Prepare the Terraform Code
Clone the repository containing the necessary Terraform, Terragrunt configurations and Kubernetes manifests, then navigate into the project directory.


```Bash
git clone https://github.com/Rajkumar-Aute/EKS-Cluster-Upgrade-with-Addons-Terragrunt.git
cd EKS-Cluster-Upgrade-with-Addons-Terragrunt
```



## Step 2: Step-by-Step Execution Commands
How to Build the Lab (Apply)
Because Terragrunt understands the dependency graph, you do not need to apply the layers one by one. Navigate to the root of your environment and run the run-all command.

```Bash
# Navigate to the environment folder
cd envs/dev

# Apply the entire stack
terragrunt run-all init -upgrade --terragrunt-non-interactive
terragrunt run-all apply --terragrunt-exclude-dir "01-network" --terragrunt-exclude-dir "02-cluster"
# It will ask for conformation type "y"
# Terragrunt will automatically build the Network first, followed by the Cluster.
```


## Step 3: Connecting to the Cluster
Once the apply is finished, you need to update your local kubeconfig to talk to the new cluster.

Update Kubeconfig

```Bash
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name>
```

2. Test Connectivity

```Bash
kubectl get nodes
```

## Step 4: Critical Verification (The 110 Pods Proof)
This is the most important part of your lab. We need to verify that the AL2023 NodeConfig actually applied the maxPods override.

1. Check Node Capacity
Run this command to see the maximum pod capacity for your new nodes:

```Bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,MAX_PODS:.status.capacity.pods,IMAGE:.status.nodeInfo.osImage
```
Success: MAX_PODS should show 110.
Verification: IMAGE should show Amazon Linux 2023.

2. Check Kubelet Arguments
If you want to see the "under the hood" config that your cloudinit generated:

```Bash
# Get the name of one of your nodes
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Check the Kubelet configuration for that node
kubectl get --raw "/api/v1/nodes/$NODE_NAME/proxy/configz" | jq '.kubeletconfig.maxPods'
```

## Step 5: IRSA & Add-ons Readiness
Since you'll be moving to 03-addons next, verify the OIDC provider is ready.

1. Verify OIDC Issuer

```Bash
aws eks describe-cluster --name <your-cluster-name> --query "cluster.identity.oidc.issuer" --output text
```

2. Verify System Pods
Ensure the VPC-CNI, CoreDNS, and Kube-Proxy are running happily on your Spot nodes.

```Bash
kubectl get pods -A
```
Note: Since you have a taint set to PREFER_NO_SCHEDULE for Spot, system pods should schedule there unless you have other nodes available.

## Step 6: High-Density Pressure Test (Optional)
To truly prove the 110 pods fix, let's try to schedule more than the default 29 pods (which is the usual limit for .large instances).

1. Deploy 50 Nginx Pods

```Bash
kubectl create deployment density-test --image=nginx --replicas=50
```

2. Watch the Scaling

```Bash
kubectl get deployment density-test -w
```
If your maxPods was stuck at 29, the deployment would hang with 20+ pods in Pending. Since you set it to 110, all 50 should reach Running on a single node!