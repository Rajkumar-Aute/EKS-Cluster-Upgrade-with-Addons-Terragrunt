# Kubernetes addons are pre built apps that runs on top of the EKS cluster and provide additional functionality.action.


###### Traffic Management (Ingress & DNS)

##### AWS Load Balancer Controller start here #####

# Create the IAM Role and Policy for the Load Balancer Controller
module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "${var.cluster_name}-aws-lbc"
  role_name_prefix = null

  # This boolean tells the module to attach the official AWS Load Balancer Controller IAM policy
  attach_load_balancer_controller_policy = true

  # Tie the IAM role securely to the specific Kubernetes ServiceAccount in the kube-system namespace
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# 2. Install the AWS Load Balancer Controller Helm Chart
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_lbc_version

  wait          = true
  wait_for_jobs = true
  timeout       = 600


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


##### AWS Load Balancer Controller ends here #####




# ##### NGINX Ingress Controller starts here #####
# # Install NGINX Ingress Controller
# resource "helm_release" "nginx_ingress" {
#   name             = "ingress-nginx"
#   repository       = "https://kubernetes.github.io/ingress-nginx"
#   chart            = "ingress-nginx"
#   namespace        = "ingress-nginx"
#   create_namespace = true
#   version          = var.nginx_ingress_version
#   timeout          = 900

#   # The magic happens in these annotations. They tell the AWS Load 
#   # Balancer Controller to build a single, high-performance Network 
#   # Load Balancer (NLB) to sit in front of NGINX.
#   # -------------------------------------------------------------
#   values = [
#     <<-EOT
#     controller:
#       replicaCount: 2 # Run two instances of NGINX for high availability
#       service:
#         annotations:
#           # Use the AWS Load Balancer Controller (external) instead of the legacy in-tree provider
#           service.beta.kubernetes.io/aws-load-balancer-type: "external"
          
#           # Provision an NLB that routes traffic directly to the pod IP addresses
#           service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
          
#           # Ensure the load balancer is public
#           service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
          
#       # Make NGINX the default ingress class for the cluster
#       ingressClassResource:
#         default: true
#     EOT
#   ]
#   depends_on = [
#     helm_release.aws_load_balancer_controller
#   ]
# }

# ##### NGINX Ingress Controller ends here #####





# ##### ExternalDNS starts here #####
# # 1. Create the IAM Role and Policy for ExternalDNS
# # Need domain name in route53 to filter the access of external dns to only the relevant hosted zone
# module "external_dns_irsa_role" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "~> 5.30"

#   role_name = "${var.cluster_name}-external-dns"
#   role_name_prefix = null


#   # This built-in flag automatically attaches the AWS-managed policy for Route53 access
#   attach_external_dns_policy = true

#   # Tie the IAM role securely to the specific Kubernetes ServiceAccount
#   oidc_providers = {
#     main = {
#       provider_arn               = var.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:external-dns"]
#     }
#   }
# }

# # 2. Install the ExternalDNS Helm Chart
# resource "helm_release" "external_dns" {
#   name       = "external-dns"
#   repository = "https://kubernetes-sigs.github.io/external-dns/"
#   chart      = "external-dns"
#   namespace  = "kube-system"
#   version    = var.external_dns_version


# values = [
#     <<-EOT
#     provider: aws
#     registry: txt
#     txtOwnerId: ${var.cluster_name}
#     policy: sync
#     domainFilters:
#       - ${var.domain_name}
#     zoneIdFilters:
#       - ${var.route53_zone_id}  # Use the variable here!
#     serviceAccount:
#       create: true
#       name: external-dns
#       annotations:
#         eks.amazonaws.com/role-arn: ${module.external_dns_irsa_role.iam_role_arn}
#     EOT
#   ]
# }

# ##### ExternalDNS ends here #####


