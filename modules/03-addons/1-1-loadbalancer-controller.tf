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

  # This boolean tells the module to attach the official AWS Load Balancer Controller IAM policy
  attach_load_balancer_controller_policy = true
  force_detach_policies                  = true

  # Tie the IAM role securely to the specific Kubernetes ServiceAccount in the kube-system namespace
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Install the AWS Load Balancer Controller using Helm Chart
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_lbc_version

  atomic          = true
  cleanup_on_fail = true
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 600
  wait            = true
  wait_for_jobs   = true


  # Pass the cluster name and the newly created IAM role ARN to the Helm chart
  values = [
    <<-EOT
    clusterName: ${var.cluster_name}
    serviceAccount:
      create: true
      name: aws-load-balancer-controller
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
  triggers = {
    cluster_name = var.cluster_name
    region       = var.aws_region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "--- Starting Mandatory EKS Cleanup ---"

      # 1. Kubernetes Level: Delete Load Balancers (ALB/NLB)
      echo "Deleting K8s Ingress and Services..."
      kubectl delete ingress --all --all-namespaces --ignore-not-found
      kubectl delete service -l service.beta.kubernetes.io/aws-load-balancer-type=external --all-namespaces --ignore-not-found
      
      # 1.5 AWS Level: Target Group Cleanup (NEW)
      # These often stay behind even after the Load Balancer is gone
      echo "Cleaning up orphaned Target Groups for cluster: ${self.triggers.cluster_name}..."
      TG_ARNS=$(aws elbv2 describe-target-groups --region ${self.triggers.region} --query "TargetGroups[?contains(TargetGroupName, 'k8s-')].TargetGroupArn" --output text)
      for tg in $TG_ARNS; do
        echo "Deleting Target Group: $tg"
        aws elbv2 delete-target-group --region ${self.triggers.region} --target-group-arn $tg || echo "Target group $tg already gone."
      done

      # 2. ASG Level: Scale to Zero
      echo "Scaling Auto Scaling Groups to 0..."
      ASG_NAMES=$(aws autoscaling describe-auto-scaling-groups --region ${self.triggers.region} --query "AutoScalingGroups[?contains(AutoScalingGroupName, '${self.triggers.cluster_name}')].AutoScalingGroupName" --output text)
      for asg in $ASG_NAMES; do
        aws autoscaling update-auto-scaling-group --region ${self.triggers.region} --auto-scaling-group-name $asg --min-size 0 --max-size 0 --desired-capacity 0
        echo "Scaled $asg to zero."
      done

      # 3. EC2 Level: Delete Orphaned Launch Templates
      echo "Deleting related Launch Templates..."
      LT_IDS=$(aws ec2 describe-launch-templates --region ${self.triggers.region} --query "LaunchTemplates[?contains(LaunchTemplateName, '${self.triggers.cluster_name}')].LaunchTemplateId" --output text)
      for lt in $LT_IDS; do
        aws ec2 delete-launch-template --region ${self.triggers.region} --launch-template-id $lt
        echo "Deleted Launch Template: $lt"
      done

      # 4. Finalizer Cleanup (Safety Net)
      # Removes the 'blocker' so Kubernetes allows the namespace to delete
      echo "Force-clearing stuck finalizers..."
      kubectl get ingress -A -o json | jq -r '.items[] | [.metadata.name, .metadata.namespace] | @tsv' | while read name ns; do
        kubectl patch ingress $name -n $ns -p '{"metadata":{"finalizers":[]}}' --type=merge --ignore-not-found
      done

      # 5. Network Level: ENI Cleanup (The Final Boss)
      # Often left by VPC-CNI or LBC; blocks Subnet deletion
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
