##### Karpenter starts here #####

# Retrieve the authentication token to pull the Karpenter image from AWS Public ECR
data "aws_ecrpublic_authorization_token" "token" {}
data "aws_caller_identity" "current" {}
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

locals {
  supported_subnets = [
    for s in data.aws_subnet.default : s.id
    if s.availability_zone != "${var.aws_region}e"
  ]
}

resource "aws_ec2_tag" "karpenter_subnets" {
  for_each    = toset(local.supported_subnets)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# AWS load balancer controller: subnet discovery tags

# The AWS LBC requires this specific tag on public subnets to know where it is allowed to provision internet-facing load balancers.
resource "aws_ec2_tag" "public_subnet_lb_tags" {
  for_each    = toset(local.supported_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# Karpenter Module
module "karpenter" {
  source       = "terraform-aws-modules/eks/aws//modules/karpenter"
  version      = "~> 20.37"
  cluster_name = var.cluster_name

  # Enable permissions required for Karpenter v1.0+
  enable_v1_permissions = true

  # Create IAM Role for Service Accounts (IRSA) for the Karpenter controller pods
  enable_irsa                     = true
  irsa_oidc_provider_arn          = var.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  # Create the IAM role that Karpenter will attach to the underlying EC2 instances it provisions
  create_node_iam_role = true
  node_iam_role_name   = "${var.cluster_name}-karpenter-node"

  # Create SQS Queue and EventBridge rules to gracefully handle Spot instance interruptions
  enable_spot_termination = true
}

# The PassRole Permissions (Fix for the Reconciler Error)

resource "aws_iam_role_policy" "karpenter_controller_pass_role" {
  name = "KarpenterControllerPassRole"
  role = module.karpenter.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = module.karpenter.node_iam_role_arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile"
        ]
        Resource = "*"
      }
    ]
  })
}

# Install the Karpenter Helm Chart

resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_version

  atomic          = false
  cleanup_on_fail = false
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 900
  wait            = false
  wait_for_jobs   = true

  values = [
    <<-EOT
    serviceAccount:
      create: true
      name: karpenter
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    
    settings:
      clusterName: ${var.cluster_name}
      interruptionQueue: ${module.karpenter.queue_name}
      featureGates:
        drift: true
    hostNetwork: true
    webhook:
      enabled: true
      port: 8443
    EOT
  ]
}

# Karpenter EC2 Node class (The "Where" and "How")

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata   = { name = "default" }
    spec = {
      amiFamily                  = "AL2023"
      amiSelectorTerms           = [{ alias = "al2023@latest" }]
      role                       = module.karpenter.node_iam_role_name
      subnetSelectorTerms        = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
      securityGroupSelectorTerms = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
    }
  })
  depends_on = [helm_release.karpenter]
}


# Karpenter node pool (The "What" and "How Much")

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["t3", "m5", "c5"] }
          ]
        }
      }
      limits = {
        cpu = "100"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
    }
  })
  depends_on = [kubectl_manifest.karpenter_node_class]
}

##### Karpenter ends here #####