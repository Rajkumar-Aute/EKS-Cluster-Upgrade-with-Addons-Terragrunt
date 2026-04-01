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
resource "null_resource" "lbc_cleanup" {
  # This resource doesn't do anything during 'apply'
  # It only triggers during 'destroy'
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "Cleaning up Load Balancer resources before destroying the controller..."
      # Delete all Ingresses (ALBs) and Services (NLBs) managed by the controller
      kubectl delete ingress --all --all-namespaces --ignore-not-found
      kubectl delete service -l service.beta.kubernetes.io/aws-load-balancer-type=external --all-namespaces --ignore-not-found
      
      # Optional: Force remove finalizers if they get stuck
      # kubectl patch ingress <name> -p '{"metadata":{"finalizers":[]}}' --type=merge
    EOT
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

##### AWS Load Balancer Controller ends here #####



# Check the ServiceAccount Annotation:
# Ensure the Helm chart correctly linked the IAM Role ARN to the Service Account.
# $ kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
