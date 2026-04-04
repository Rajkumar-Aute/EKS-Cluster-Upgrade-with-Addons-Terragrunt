# This is the "hook" that pulls in the remote_state and providers configurations from the root.hcl file.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load the global environment variables from env/<respective-env>/env.hcl file
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

# Where the terraform code resides.
terraform {
  source = "../../../modules/03-addons"
}

dependency "network" {
  config_path = "../01-network"
  
  mock_outputs = {
    vpc_id = "vpc-12345"
  }
}

dependency "cluster" {
  config_path = "../02-cluster"

  # Dummy output as terragrunt expects while running plan before the cluster exists
  mock_outputs = {
    cluster_endpoint                   = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
    cluster_name                       = "mock-cluster"
    oidc_provider_arn                  = "arn:aws:iam::123456789012:oidc-provider/mock"
  }
}

# Inject all variables into the Addons module (TOP LEVEL)
inputs = {
  # Static versions and region from env.hcl
  aws_region                    = local.env_vars.locals.aws_region
  cluster_name                  = local.env_vars.locals.cluster_name
  vpc_id                        = dependency.network.outputs.vpc_id
  karpenter_version             = local.env_vars.locals.karpenter_version
  keda_version                  = local.env_vars.locals.keda_version
  cert_manager_version          = local.env_vars.locals.cert_manager_version
  nginx_ingress_version         = local.env_vars.locals.nginx_ingress_version
  aws_lbc_version               = local.env_vars.locals.aws_lbc_version
  external_dns_version          = local.env_vars.locals.external_dns_version
  external_secrets_version      = local.env_vars.locals.external_secrets_version
  kyverno_version               = local.env_vars.locals.kyverno_version
  trivy_operator_version        = local.env_vars.locals.trivy_operator_version
  metrics_server_version        = local.env_vars.locals.metrics_server_version
  kube_prometheus_stack_version = local.env_vars.locals.kube_prometheus_stack_version

  # Dynamic values from the Cluster dependency
  cluster_endpoint                   = dependency.cluster.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.cluster.outputs.cluster_certificate_authority_data
  oidc_provider_arn                  = dependency.cluster.outputs.oidc_provider_arn
}
