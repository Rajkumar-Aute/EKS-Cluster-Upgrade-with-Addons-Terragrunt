locals {
  environment        = "dev"
  aws_region         = "us-east-1"
  cluster_name       = "eks-upgrade-lab-${local.environment}"

  # Upgraded Cluster Version
  cluster_version    = "1.35"
  eks_capacity_type  = "SPOT"
  eks_instance_types = ["c6a.large", "c7a.large", "m6a.large", "m7a.large"]

  domain_name = "eks.devsecopsguru.in"

  min_node_groups_nodes     = 1
  max_node_groups_nodes     = 3
  desired_node_groups_nodes = 2

  # terraform provider versions
  provider_versions = {
    aws        = "5.0"
    helm       = "3.0"
    kubernetes = "3.0"
    kubectl    = "1.14.0"
  }

  # Upgraded Addon Versions
  karpenter_version             = "1.1.1"
  keda_version                  = "2.16.0"
  cert_manager_version          = "v1.15.3"
  nginx_ingress_version         = "4.11.2"
  aws_lbc_version               = "1.8.1"
  external_dns_version          = "1.15.0"
  external_secrets_version      = "0.10.4"
  kyverno_version               = "3.3.0"
  trivy_operator_version        = "0.21.0"
  metrics_server_version        = "3.12.2"
  kube_prometheus_stack_version = "61.3.0"
}