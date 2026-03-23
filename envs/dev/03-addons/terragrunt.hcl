# environments/dev/03-addons/terragrunt.hcl

# 1. Load the global environment variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

# This is the "hook" that pulls in the remote_state and providers from the root
include "root" {
  path = find_in_parent_folders()
}

# 2. Point to the shared Terraform code and define the automated cleanup hook
terraform {
  source = "../../../modules/03-addons"
#  before_hook "clean_ghost_helm_releases" {
#    commands = ["apply"]
#    execute  = [
#      "bash", "-c",
#      <<-EOT
#      # 1. Update kubeconfig
#      aws eks update-kubeconfig --name EKS-upgrade-lab --region us-east-1
#      
#      # 2. Delete the specific webhooks that block installations
#      kubectl delete validatingwebhookconfigurations --all --ignore-not-found
#      kubectl delete mutatingwebhookconfigurations --all --ignore-not-found
#      
#      # 3. Clear any Helm "Pending" secrets that block the release
#      kubectl delete secret -l owner=helm --all-namespaces --ignore-not-found
#      
#      # 4. Force delete stuck pods in Terminating state (optional but helpful)
#      kubectl get pods -A | grep Terminating | awk '{print $2 " --namespace=" $1}' | xargs -I {} kubectl delete pod {} --force --grace-period=0 || true
#      
#      # Clear Helm records that think the release is "failed"
#      kubectl delete secret -l owner=helm,name=cert-manager -n cert-manager --ignore-not-found
#      EOT
#    ]
#  }
}

# 3. Fetch dynamic outputs from the Cluster Layer
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
    karpenter_iam_role_arn             = "arn:aws:iam::123456789012:role/mock"
    karpenter_queue_name               = "mock-queue"
  }
}

# 4. Inject all variables into the Addons module
inputs = {
  # Static versions and region from env.hcl
  aws_region                    = local.env_vars.locals.aws_region
  cluster_name                  = local.env_vars.locals.cluster_name
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
  karpenter_iam_role_arn             = dependency.cluster.outputs.karpenter_iam_role_arn
  karpenter_queue_name               = dependency.cluster.outputs.karpenter_queue_name
}