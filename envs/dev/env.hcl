locals {
  environment  = "dev"
  aws_region   = "us-east-1"
  cluster_name    = "eks-upgrade-lab-${local.environment}"
  cluster_version = "1.34"

  domain_name = "eks.devsecopsguru.in"
  
  min_node_groups_nodes = 1
  max_node_groups_nodes = 2
  desired_node_groups_nodes = 1



  karpenter_version             = "1.0.1"
  cert_manager_version          = "v1.14.4"
  nginx_ingress_version         = "4.10.1"
  aws_lbc_version               = "1.7.2"
  external_dns_version          = "1.14.3"
  external_secrets_version      = "0.9.13"
  kyverno_version               = "3.2.5"
  trivy_operator_version        = "0.32.1"
  metrics_server_version        = "3.12.1"
  kube_prometheus_stack_version = "58.2.2"

  # cluster_version = "1.35" # Upgraded from 1.34
  # 
  # # Upgraded Helm Chart Versions
  # karpenter_version             = "1.1.1"
  # cert_manager_version          = "v1.15.3"
  # nginx_ingress_version         = "4.11.2"
  # aws_lbc_version               = "1.8.1"
  # external_dns_version          = "1.15.0"
  # external_secrets_version      = "0.10.4"
  # kyverno_version               = "3.3.0"
  # trivy_operator_version        = "0.21.0"
  # metrics_server_version        = "3.12.2"
  # kube_prometheus_stack_version = "61.3.0"




}