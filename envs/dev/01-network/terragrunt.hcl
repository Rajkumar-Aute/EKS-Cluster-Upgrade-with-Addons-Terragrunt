# environments/dev/01-network/terragrunt.hcl

# 1. Load the global environment variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

# 2. Point to the shared Terraform code
terraform {
  source = "../../../modules/01-network"
}

# 3. Inject variables into the Network module
inputs = {
  aws_region    =   local.env_vars.locals.aws_region
  cluster_name = local.env_vars.locals.cluster_name
  cluster_version   =   local.env_vars.locals.cluster_version
  
  
}