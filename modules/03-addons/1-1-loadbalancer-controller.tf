##### AWS Load Balancer Controller start here #####

# Variables for AWS Load Balancer Controller
variable "aws_lbc_version" {
  description = "Helm chart version for AWS Load Balancer Controller"
  type        = string
}

# Create the IAM Role and Policy for the Load Balancer Controller
module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name        = "${var.cluster_name}-aws-lbc"
  role_name_prefix = null

  # Attach the AWS Load Balancer Controller IAM policy
  attach_load_balancer_controller_policy = true
  # Destroy by terraform when the module is removed, preventing orphaned policies.
  force_detach_policies                  = true

  # Tie the IAM role securely to the specific Kubernetes ServiceAccount in the kube-system namespace
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Install the AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_lbc_version

  # Reliability flags:
  #  Automatically roll back to the previous version if the upgrade fails.
  atomic          = true
  # Deletes new resources created during a failed deployment
  cleanup_on_fail = true
  # Forces resource updates through replacement if in-place updates fail.
  force_update    = true
  # Runs 'helm lint' before deployment to catch syntax errors in the chart.
  lint            = true
  # Restarts pods on upgrade to ensure they pick up new configurations or secrets.
  recreate_pods   = true
  # Reuse a release name if the previous one is stuck in a bad state.
  replace         = true
  # Gives the controller pods time to start and report as "Ready".
  timeout         = 600
  # Tells Terraform to wait until all resources are in a ready state before continuing.
  wait            = true
  # Ensures any pre-install or post-install Helm hooks complete successfully.
  wait_for_jobs   = true

  # This values block translates to the customized values.yaml file used by Helm.
  values = [
    <<-EOT
    clusterName: ${var.cluster_name}
    serviceAccount:
      create: true
      name: aws-load-balancer-controller
      # This annotation is the critical link between Kubernetes and AWS IAM.
      # It tells the pod which IAM Role to assume using the OIDC provider.
      annotations:
        eks.amazonaws.com/role-arn: ${module.aws_load_balancer_controller_irsa_role.iam_role_arn}
    EOT
  ]
  
  depends_on = [
    module.aws_load_balancer_controller_irsa_role
  ]
}


# The Auto-Cleanup Resource
resource "null_resource" "eks_deep_cleanup" {
  # Triggers act as a state cache. During a 'destroy' operation, Terraform might lose access 
  triggers = {
    cluster_name = var.cluster_name
    region       = var.aws_region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "--- Starting Mandatory EKS Cleanup ---"

      # Kubernetes Level: Delete Load Balancers (ALB/NLB)
      # By deleting Ingresses and external Services, we signal the Load Balancer Controller to delete the associated ALBs/NLBs in AWS before the controller itself is destroyed.
      echo "Deleting K8s Ingress and Services..."
      kubectl delete ingress --all --all-namespaces --ignore-not-found
      kubectl delete service -l service.beta.kubernetes.io/aws-load-balancer-type=external --all-namespaces --ignore-not-found
      
      # Orphaned Target Groups prevent VPC subnets and Security Groups from being deleted.
      echo "Cleaning up orphaned Target Groups for cluster: ${self.triggers.cluster_name}..."
      TG_ARNS=$(aws elbv2 describe-target-groups --region ${self.triggers.region} --query "TargetGroups[?contains(TargetGroupName, 'k8s-')].TargetGroupArn" --output text)
      for tg in $TG_ARNS; do
        echo "Deleting Target Group: $tg"
        aws elbv2 delete-target-group --region ${self.triggers.region} --target-group-arn $tg || echo "Target group $tg already gone."
      done

      # If Terraform deletes an EC2 node, the Auto Scaling Group will immediately try to spin up a new one.
      # This new node will grab a subnet IP and prevent the VPC from being destroyed. Scaling to 0 stops this loop.
      echo "Scaling Auto Scaling Groups to 0..."
      ASG_NAMES=$(aws autoscaling describe-auto-scaling-groups --region ${self.triggers.region} --query "AutoScalingGroups[?contains(AutoScalingGroupName, '${self.triggers.cluster_name}')].AutoScalingGroupName" --output text)
      for asg in $ASG_NAMES; do
        aws autoscaling update-auto-scaling-group --region ${self.triggers.region} --auto-scaling-group-name $asg --min-size 0 --max-size 0 --desired-capacity 0
        echo "Scaled $asg to zero."
      done

      # Delete Orphaned Launch Templates EKS Managed Node Groups often generate hidden launch templates that Terraform doesn't track in its state file.
      echo "Deleting related Launch Templates..."
      LT_IDS=$(aws ec2 describe-launch-templates --region ${self.triggers.region} --query "LaunchTemplates[?contains(LaunchTemplateName, '${self.triggers.cluster_name}')].LaunchTemplateId" --output text)
      for lt in $LT_IDS; do
        aws ec2 delete-launch-template --region ${self.triggers.region} --launch-template-id $lt
        echo "Deleted Launch Template: $lt"
      done

      # Finalizer Cleanup. If the Load Balancer Controller pods die before they finish deleting the ALBs, Kubernetes will keep the Ingress objects in a "Terminating" state forever due to finalizers, which hangs the whole Terraform destroy process.
      echo "Force-clearing stuck finalizers..."
      kubectl get ingress -A -o json | jq -r '.items[] | [.metadata.name, .metadata.namespace] | @tsv' | while read name ns; do
        kubectl patch ingress $name -n $ns -p '{"metadata":{"finalizers":[]}}' --type=merge --ignore-not-found
      done

      # ENI Cleanup. The AWS VPC-CNI creates Elastic Network Interfaces directly on EC2 instances.
      echo "Detecting orphaned Network Interfaces..."
      ENI_IDS=$(aws ec2 describe-network-interfaces --region ${self.triggers.region} --filters "Name=description,Values=*${self.triggers.cluster_name}*" --query "NetworkInterfaces[*].NetworkInterfaceId" --output text)
      for eni in $ENI_IDS; do
        echo "Deleting ENI: $eni"
        aws ec2 delete-network-interface --region ${self.triggers.region} --network-interface-id $eni || echo "ENI $eni in use, skipping..."
      done

      echo "--- Cleanup Sequence Complete ---"
    EOT
  }
}

##### AWS Load Balancer Controller ends here #####


# Check the ServiceAccount Annotation:
# Ensure the Helm chart correctly linked the IAM Role ARN to the Service Account.
# $ kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
