# Load the global environment variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../modules/03-addons"

  #  before_hook "clean_ghost_releases" {
  #    commands = ["apply"]
  #    execute  = [
  #      "bash",
  #      "-c",
  #      <<-EOT
  #        echo "Cleaning up potential ghost Helm secrets..."
  #        # List of addon names to check
  #        ADDONS=("external-dns" "kyverno" "external-secrets" "aws-load-balancer-controller" "trivy-operator" "kube-prometheus-stack")
  #        for addon in "$${ADDONS[@]}"; do
  #          kubectl delete secret -n kube-system -l "name=$addon,owner=helm" 2>/dev/null || true
  #          kubectl delete secret -n monitoring -l "name=$addon,owner=helm" 2>/dev/null || true
  #          kubectl delete secret -n kyverno -l "name=$addon,owner=helm" 2>/dev/null || true
  #        done
  #        echo "Cleanup complete. Proceeding with Terragrunt Apply."
  #      EOT
  #    ]
  #  }
}



# Include root config (Remote State/Providers)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "network" {
  config_path = "../01-network"
}

dependency "cluster" {
  config_path = "../02-cluster"


  #  mock_outputs_allowed_terraform_commands = ["apply", "plan", "validate", "destroy"]
  #  skip_outputs = get_terraform_command() == "destroy" ? true : false
  # Mocks allow 'terragrunt validate' or 'plan' to work even if the cluster isn't built yet
  mock_outputs = {
    cluster_endpoint                   = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
    cluster_name                       = "mock-cluster"
    oidc_provider_arn                  = "arn:aws:iam::123456789012:oidc-provider/mock"
  }
}

# Inject all variables into the Addons module
inputs = {
  # Static versions and region from env.hcl
  aws_region                    = local.env_vars.locals.aws_region
  cluster_name                  = local.env_vars.locals.cluster_name
  vpc_id                        = dependency.network.outputs.vpc_id
  karpenter_version             = local.env_vars.locals.karpenter_version
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