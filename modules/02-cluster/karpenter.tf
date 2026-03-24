
# Karpenter is a next-generation cluster autoscaler that can rapidly provision new nodes in response to unschedulable pods. It offers more flexibility and faster scaling than the traditional Cluster Autoscaler, especially in environments with Spot instances.

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.37"

  cluster_name = module.eks.cluster_name

  # Enable permissions required for Karpenter v1.0+
  enable_v1_permissions = true

  # Create IAM Role for Service Accounts (IRSA) for the Karpenter controller pods
  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Create the IAM role that Karpenter will attach to the underlying EC2 instances it provisions
  create_node_iam_role = true
  node_iam_role_name   = "${var.cluster_name}-karpenter-node"

  # Create SQS Queue and EventBridge rules to gracefully handle Spot instance interruptions
  enable_spot_termination = true
}