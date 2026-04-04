# EKS cluster deployment using Terragrunt

Terragrunt, the deployment flow is slightly different than standard Terraform.

## Prerequisites & Windows Setup

If you are running this on a Windows machine, you must configure your environment to handle Terraform's deep nested directory structures, or you will encounter Filename too long errors.

Open your Git Bash terminal and run:

```

# Tell Git to ignore the Windows 260-character path limit

git config --global core.longpaths true

```

## Step 1: Prepare the Terraform Code

Clone the repository containing the necessary Terraform, Terragrunt configurations and Kubernetes manifests, then navigate into the project directory.

```
git clone https://github.com/Rajkumar-Aute/EKS-Cluster-Upgrade-with-Addons-Terragrunt.git
cd EKS-Cluster-Upgrade-with-Addons-Terragrunt
```

## Step 2: Step-by-Step Execution Commands

How to Build the Lab (Apply)
Because Terragrunt understands the dependency graph, you do not need to apply the layers one by one. Navigate to the root of your environment and run the run-all command.

```

# Navigate to the environment folder

cd envs/dev

# Apply the entire stack

terragrunt run-all init -upgrade --terragrunt-non-interactive
terragrunt run-all apply --terragrunt-exclude-dir "01-network" --terragrunt-exclude-dir "02-cluster"

# It will ask for conformation type "y"

# Terragrunt will automatically build the Network first, followed by the Cluster

```

## Step 3: Connecting to the Cluster

Once the apply is finished, you need to update your local kubeconfig to talk to the new cluster.

Update Kubeconfig

```
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name>
```

1. Test Connectivity

```
kubectl get nodes

```

## Step 4: IRSA & Add-ons Readiness

Since you'll be moving to 03-addons next, verify the OIDC provider is ready.

1. Verify OIDC Issuer

```
aws eks describe-cluster --name <your-cluster-name> --query "cluster.identity.oidc.issuer" --output text
```

1. Verify System Pods
Ensure the VPC-CNI, CoreDNS, and Kube-Proxy are running happily on your Spot nodes.

```
kubectl get pods -A

```

Note: Since you have a taint set to PREFER_NO_SCHEDULE for Spot, system pods should schedule there unless you have other nodes available.


#######################################################

Deploy application on EKS Auto Mode worker nodes.

Auto Mode work is the nodeSelector. Because we enabled the *general-purpose and system* node pools in Terraform, Auto Mode will see these manifests, realize there are no nodes available, and automatically provision a Spot EC2 instance.

# Step: 1:

Create yaml file app-spot.yaml
```YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: expo-sample-app
  namespace: default
  labels:
    app: expo-sample
spec:
  replicas: 2
  selector:
    matchLabels:
      app: expo-sample
  template:
    metadata:
      labels:
        app: expo-sample
    spec:
      # --- EKS AUTO MODE SPECIFIC CONFIG ---
      nodeSelector:
        # 1. Force the app onto the Auto Mode managed pool
        eks.amazonaws.com/compute-type: auto
        # 2. Tell Auto Mode to specifically use SPOT instances for cost savings
        eks.amazonaws.com/capacityType: SPOT
      
      containers:
      - name: web-server
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          # Auto Mode uses these numbers to pick the EC2 instance size!
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "1Gi"
---
apiVersion: v1
kind: Service
metadata:
  name: expo-sample-service
  namespace: default
spec:
  selector:
    app: expo-sample
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  # Since you enabled Auto Networking in Terraform, 
  # EKS will automatically create an AWS NLB for this service.
  type: LoadBalancer
```


## Step 2: Deploy and Verify
Apply the manifest:

```
kubectl apply -f app-spot.yaml
```

For the first 60–90 seconds, your pods will be in Pending state. You can watch Auto Mode provision the node by running:

```
# Watch the nodes appear in real-time
kubectl get nodes -w
```

Check the Instance Type:
Once the node appears, check if it actually created a Spot instance and what type it chose:

```
kubectl get nodes -l eks.amazonaws.com/capacityType=SPOT
```