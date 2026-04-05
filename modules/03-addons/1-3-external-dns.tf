# Variables and resources for setting up ExternalDNS with Route53
variable "domain_name" {
  description = "The domain name to use for the cluster (e.g., eks.devsecopsguru.in)"
  type        = string
}

# outputs for Route53 zone information
output "subnet_zone_id" {
  description = "Mapping of subnet IDs to their availability zones"
  value       = aws_route53_zone.subdomain.zone_id
}

output "subdomain_name_servers" {
  description = "The Name Servers for the eks.devsecopsguru.in hosted zone. Add these as NS records in your root domain provider."
  value       = aws_route53_zone.subdomain.name_servers
}

output "subdomain_zone_id" {
  description = "The Hosted Zone ID for the subdomain"
  value       = aws_route53_zone.subdomain.zone_id
}

# route53 zone for the subdomain
resource "aws_route53_zone" "subdomain" {
  name    = var.domain_name
  comment = "Hosted Zone for EKS Ingress managed by Terraform"
}


##### ExternalDNS starts here #####
# Create the IAM Role and Policy for ExternalDNS
module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name        = "${var.cluster_name}-external-dns"
  role_name_prefix = null
  attach_external_dns_policy = true
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

# Install the ExternalDNS using Helm Chart
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = var.external_dns_version

  atomic          = true
  cleanup_on_fail = true
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 600
  wait            = true
  wait_for_jobs   = true

  values = [
    <<-EOT
    provider: aws
    registry: txt
    txtOwnerId: ${var.cluster_name}
    policy: sync
    domainFilters:
      - var.domain_name
    zoneIdFilters:
      - ${aws_route53_zone.subdomain.zone_id} 
    serviceAccount:
      create: true
      name: external-dns
      annotations:
        eks.amazonaws.com/role-arn: ${module.external_dns_irsa_role.iam_role_arn}
    EOT
  ]
  depends_on = [
    module.external_dns_irsa_role,
    aws_route53_zone.subdomain
  ]
}

##### ExternalDNS ends here #####


# Verify the AWS Side (Route53 & IAM)
# First, confirm the Hosted Zone exists and the IAM role is correctly linked to your EKS cluster.
# Check if Hosted Zone is active:

# $ aws route53 list-hosted-zones-by-name --dns-name eks.devsecopsguru.in

# Verify the ServiceAccount Annotation:
# The Helm chart should have annotated the ServiceAccount with your IAM Role ARN.
# $ kubectl get sa external-dns -n kube-system -o yaml

# Look for the eks.amazonaws.com/role-arn line.
# Verify the Pod Health (The "Logic" Layer)
# Check Pod Status:

# $ kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns