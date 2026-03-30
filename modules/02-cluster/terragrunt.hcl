include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "network" {
  config_path = "../01-network"
}

locals {
  env_vars = local.env_vars.locals.module_versions.module_eks_version
  module_eks_var = local.env_vars.local.version
}

terraform {
  source  = "tfr:///terraform-aws-modules/eks/aws?version=${local.module_eks_var}
}

# Pass the outputs from Network directly into the Cluster variables
inputs = {
  vpc_id     = dependency.network.outputs.vpc_id
  subnet_ids = dependency.network.outputs.subnet_ids
}