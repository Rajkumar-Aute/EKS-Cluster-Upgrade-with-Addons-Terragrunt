# EKS Upgrade and with Addons Operators using Terraform and Terragrunt.

Why we are using Terragrunt along with terraform.


Managing Amazon EKS with Terraform and Helm charts is powerful, but tearing it down often results in hanging state files and stuck Kubernetes Finalizers. This guide provides a production-grade, three-tier Terragrunt architecture that provisions and destroys an entire EKS ecosystem flawlessly.



### Prerequisites & Windows Setup
If you are running this on a Windows machine, you must configure your environment to handle Terraform's deep nested directory structures, or you will encounter Filename too long errors.

Open your Git Bash terminal and run:

```Bash
# 1. Tell Git to ignore the Windows 260-character path limit
git config --global core.longpaths true

# 2. Redirect Terragrunt's heavy cache to a short path at the root of your drive
mkdir -p /c/tg_cache
export TERRAGRUNT_DOWNLOAD="/c/tg_cache"
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
terragrunt run-all apply --terragrunt-non-interactive
# It will ask for conformation type "y"
# Terragrunt will automatically build the Network first, followed by the Cluster, and finally the Addons.
# terragrunt run-all apply --terragrunt-exclude-dir "03-addons"    --terragrunt-non-interactive
# terragrunt run-all apply --terragrunt-exclude-dir "01-network" --terragrunt-exclude-dir "02-cluster" --terragrunt-exclude-dir "03-addons" --terragrunt-non-interactive

```







# How to Teardown the Lab (Destroy)
Destroying an EKS cluster with active LoadBalancers and Admission Webhooks usually requires heavy manual intervention.

### Step 1: Authenticate to the Cluster
Before you can clean up Kubernetes, ensure your terminal is actively communicating with your EKS control plane.

```Bash
aws eks update-kubeconfig --name eks-upgrade-lab-<env> --region us-east-1
```

### Step 2: Nuke the Admission Webhooks (Kyverno)
Kyverno intercepts API requests to validate them. If you delete the cluster nodes before deleting these webhooks, the EKS control plane will panic because it can't reach Kyverno to validate the deletion of other resources.

```Bash
# Delete Validating Webhooks
kubectl delete validatingwebhookconfigurations -l app.kubernetes.io/name=kyverno --ignore-not-found

# Delete Mutating Webhooks
kubectl delete mutatingwebhookconfigurations -l app.kubernetes.io/name=kyverno --ignore-not-found
```

### Step 3: Delete the Load Balancers (Nginx)
The Nginx Ingress Controller spun up a physical AWS Elastic Load Balancer (ELB). We need to tell AWS to delete this hardware before Terraform rips out the VPC subnets underneath it.

```Bash
kubectl delete svc -A -l app.kubernetes.io/managed-by=Helm
# Note: This command will hang for a few minutes while AWS physically deletes the ELB. Let it finish.
```

### Step 4: Force-Clear Stubborn Finalizers (The Backup Plan)
If Step 3 hangs indefinitely (meaning the AWS Load Balancer Controller is already dead and can't perform the deletion), you must manually break the lock on the service. Open a second terminal window and run:

``` Bash
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"metadata":{"finalizers":null}}' --type merge
# Once you run this, your stuck command from Step 3 should immediately complete.
```

### Step 5: Clean Up Persistent Storage (EBS Volumes)
If you deployed any stateful applications that requested persistent storage (PVCs), delete them now so the underlying AWS EBS volumes are cleanly detached and deleted, preventing zombie charges on your AWS bill.

```Bash
kubectl delete pvc --all -A
```

### Step 6: Execute the Global Destroy
Once the webhooks are gone, the ELBs are deleted, and the PVCs are cleared, your cluster is completely "hollowed out" and safe to destroy.

Navigate back to your environment root and trigger Terragrunt:

```Bash
# Ensure your local kubeconfig is updated so the hook can talk to the cluster
aws eks update-kubeconfig --name EKS-upgrade-lab --region us-east-1

# Trigger the global destroy
cd env/dev
terragrunt run-all destroy --terragrunt-ignore-external-dependencies --terragrunt-non-interactive
```