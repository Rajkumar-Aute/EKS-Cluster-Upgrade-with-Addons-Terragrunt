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


## Step 4: IRSA & Add-ons Readiness
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
