# EKS Upgrade and with Addons Operators using Terraform and Terragrunt.

Why we are using Terragrunt along with terraform.


Managing Amazon EKS with Terraform and Helm charts is powerful, but tearing it down often results in hanging state files and stuck Kubernetes Finalizers. This guide provides a production-grade, three-tier Terragrunt architecture that provisions and destroys an entire EKS ecosystem flawlessly.



### Prerequisites & Windows Setup
If you are running this on a Windows machine, you must configure your environment to handle Terraform's deep nested directory structures, or you will encounter Filename too long errors.

Open your Git Bash terminal and run:

```Bash
# 1. Tell Git to ignore the Windows 260-character path limit
git config --global core.longpaths true

# Configure AWS config with aws secret key and secret access key.
aws configure
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

#### Note: remove .disabled from ./modules/03-addons directory to enable required addons. and you can verify the addons after deploying by reading respective addon readme file.

```Bash
# Navigate to the environment folder
cd envs/dev

# Apply the entire stack, terragrunt will automatically do init, if we get error to initiate the terragrunt or terraform we need to run below command.
terragrunt run-all init -upgrade --terragrunt-non-interactive
# All module build automatically, first network, followed by the cluster, and finally the addons.
terragrunt run-all apply --terragrunt-non-interactive

# Terragrunt will automatically build the Network first, followed by the Cluster, and  no Addons will be installed as by using flag "--terragrunt-exclude-dir "03-addons"".
terragrunt run-all apply --terragrunt-exclude-dir "03-addons"    --terragrunt-non-interactive
# It will not ask for conformation type "y" as we added flag "--terragrunt-non-interactive
```


# How to Teardown the Lab (Destroy)
Destroying an EKS cluster with active LoadBalancers and Admission Webhooks usually requires heavy manual intervention.

## Step 2: Execute the Global Destroy
Once the webhooks are gone, the ELBs are deleted, and the PVCs are cleared, your cluster is completely "hollowed out" and safe to destroy.

Navigate back to your environment root and trigger Terragrunt:

```Bash
# Trigger the global destroy
cd env/dev
terragrunt run-all destroy --terragrunt-ignore-external-dependencies --terragrunt-non-interactive
# by adding some time terragrunt might fail due to dependencies so by adding flag "--terragrunt-ignore-external-dependencies" it will ignore dependencies.
```

Update kubeconfig file
```
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name>
```