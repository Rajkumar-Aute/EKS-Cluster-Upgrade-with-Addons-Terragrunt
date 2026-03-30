# This is the "hook" that pulls in the remote_state and providers from the root
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load the global environment variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

# Point to the shared Terraform code
terraform {
  source = "../../../modules/01-network"
}

# Inject variables into the Network module
inputs = {
  aws_region      = local.env_vars.locals.aws_region
  cluster_name    = local.env_vars.locals.cluster_name
  cluster_version = local.env_vars.locals.cluster_version
}