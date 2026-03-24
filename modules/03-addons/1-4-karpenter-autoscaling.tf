# Kubernetes addons are pre built apps that runs on top of the EKS cluster and provide additional functionality.action.



##### Karpenter starts here #####
# Karpenter

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.37"

  cluster_name = var.cluster_name

  # Enable permissions required for Karpenter v1.0+
  enable_v1_permissions = true

  # Create IAM Role for Service Accounts (IRSA) for the Karpenter controller pods
  enable_irsa            = true
  irsa_oidc_provider_arn = var.oidc_provider_arn

  # Create the IAM role that Karpenter will attach to the underlying EC2 instances it provisions
  create_node_iam_role = true
  node_iam_role_name   = "${var.cluster_name}-karpenter-node"

  # Create SQS Queue and EventBridge rules to gracefully handle Spot instance interruptions
  enable_spot_termination = true
}


# Retrieve the authentication token to pull the Karpenter image from AWS Public ECR



data "aws_ecrpublic_authorization_token" "token" {}
data "aws_caller_identity" "current" {}

# Karpenter needs permissions to pass the node role when it creates EC2 instances, so we need to add an additional policy to the Karpenter controller's IAM role.
resource "aws_iam_role_policy" "karpenter_controller_pass_role" {
  name = "KarpenterControllerPassRole"
  role = module.karpenter.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        # This MUST be the ARN of the role your NODES will use
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-karpenter-node"
      },
      {
        # Karpenter also needs to manage the Instance Profiles themselves
        Action   = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}


# # Install the Karpenter Helm Chart
# resource "helm_release" "karpenter" {
#   namespace           = "karpenter"
#   create_namespace    = true
#   name                = "karpenter"
#   repository          = "oci://public.ecr.aws/karpenter"
#   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
#   repository_password = data.aws_ecrpublic_authorization_token.token.password
#   chart               = "karpenter"
#   version             = var.karpenter_version

#   force_update    = true
#   recreate_pods   = true
#   cleanup_on_fail = true
#   atomic          = false
#   timeout         = 900
#   wait           = true


#   values = [
#     <<-EOT
#     serviceAccount:
#       annotations:
#         # Attaches the IRSA IAM role we created earlier to the pod
#         eks.amazonaws.com/role-arn: ${var.karpenter_iam_role_arn}
#     settings:
#       clusterName: ${var.cluster_name}
#       interruptionQueue: ${var.karpenter_queue_name}
#       featureGates:
#         drift: true
#     EOT
#   ]
#   depends_on = [helm_release.aws_load_balancer_controller]
# }



# # KARPENTER EC2 NODE CLASS (The "Where" and "How")
# resource "kubectl_manifest" "karpenter_node_class" {
#   yaml_body = yamlencode({
#     apiVersion = "karpenter.k8s.aws/v1"
#     kind       = "EC2NodeClass"
#     metadata   = { name = "default" }
#     spec = {
#       amiFamily                  = "AL2023"
#       amiSelectorTerms           = [{ alias = "al2023@latest" }]
#       role                       = module.karpenter.node_iam_role_name
#       subnetSelectorTerms        = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
#       securityGroupSelectorTerms = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
#     }
#   })
#   # This dependency now works perfectly!
#   depends_on = [helm_release.karpenter]
# }
# # -------------------------------------------------------------
# # KARPENTER NODE POOL (The "What" and "How Much")
# # -------------------------------------------------------------
# resource "kubectl_manifest" "karpenter_node_pool" {
#   yaml_body = yamlencode({
#     apiVersion = "karpenter.sh/v1"
#     kind       = "NodePool"
#     metadata = {
#       name = "default"
#     }
#     spec = {
#       template = {
#         spec = {
#           nodeClassRef = {
#             group = "karpenter.k8s.aws"
#             kind  = "EC2NodeClass"
#             name  = "default"
#           }
#           requirements = [
#             # Only use Spot instances for cost savings
#             { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
#             # Allow t3, m5, and c5 instance families
#             { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["t3", "m5", "c5"] }
#           ]
#         }
#       }
#       # Hard limit to protect your AWS bill
#       limits = {
#         cpu = "100"
#       }
#       # Consolidation: Karpenter will constantly try to pack pods tightly and delete empty nodes
#       disruption = {
#         consolidationPolicy = "WhenEmptyOrUnderutilized"
#         consolidateAfter    = "1m"
#       }
#     }
#   })
#   depends_on = [kubectl_manifest.karpenter_node_class]
# }

# ##### Karpenter ends here #####