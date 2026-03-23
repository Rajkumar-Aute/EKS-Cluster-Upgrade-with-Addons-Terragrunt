# Kubernetes addons are pre built apps that runs on top of the EKS cluster and provide additional functionality.action.



##### Karpenter starts here #####
# Karpenter
# Retrieve the authentication token to pull the Karpenter image from AWS Public ECR

data "aws_ecrpublic_authorization_token" "token" {}

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

  force_update    = true
  recreate_pods   = true
  cleanup_on_fail = true
  atomic          = false


  values = [
    <<-EOT
    serviceAccount:
      annotations:
        # Attaches the IRSA IAM role we created earlier to the pod
        eks.amazonaws.com/role-arn: ${var.karpenter_iam_role_arn}
    settings:
      # Tells Karpenter which cluster it is managing
      clusterName: ${var.cluster_name}
      # Tells Karpenter which SQS queue to listen to for Spot interruptions
      interruptionQueue: ${var.karpenter_queue_name}
    EOT
  ]
  depends_on = [helm_release.aws_load_balancer_controller]
}



# KARPENTER EC2 NODE CLASS (The "Where" and "How")
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata   = { name = "default" }
    spec = {
      amiFamily                  = "AL2023"
      amiSelectorTerms           = [{ alias = "al2023@latest" }]
      role                       = "${var.cluster_name}-karpenter-node"
      subnetSelectorTerms        = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
      securityGroupSelectorTerms = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
    }
  })
  # This dependency now works perfectly!
  depends_on = [helm_release.karpenter]
}
# -------------------------------------------------------------
# KARPENTER NODE POOL (The "What" and "How Much")
# -------------------------------------------------------------
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
            # Only use Spot instances for cost savings
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
            # Allow t3, m5, and c5 instance families
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["t3", "m5", "c5"] }
          ]
        }
      }
      # Hard limit to protect your AWS bill
      limits = {
        cpu = "100"
      }
      # Consolidation: Karpenter will constantly try to pack pods tightly and delete empty nodes
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
    }
  })
  depends_on = [kubectl_manifest.karpenter_node_class]
}

##### Karpenter ends here #####