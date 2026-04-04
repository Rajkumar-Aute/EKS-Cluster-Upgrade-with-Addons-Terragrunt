# This is the "hook" that pulls in the remote_state and providers configurations from the root.hcl file.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load the global environment variables form env/<respective-env>/env.hcl file
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

# Where the terraform code resides.
terraform {
  source = "../../../modules/02-cluster"
}

# Inject variables into the Network module from terraform code variable.tf file
inputs = {
  # Static variables from env.hcl
  aws_region                = local.env_vars.locals.aws_region
  cluster_name              = local.env_vars.locals.cluster_name
  cluster_version           = local.env_vars.locals.cluster_version
  min_node_groups_nodes     = local.env_vars.locals.min_node_groups_nodes
  max_node_groups_nodes     = local.env_vars.locals.max_node_groups_nodes
  desired_node_groups_nodes = local.env_vars.locals.desired_node_groups_nodes

  # Dynamic variables from the Network dependency
  vpc_id     = dependency.network.outputs.vpc_id
  subnet_ids = dependency.network.outputs.subnet_ids
}

# Fetch outputs from the Network Layer
dependency "network" {
  config_path = "../01-network"

  # Mocks allow you to run 'plan' before the VPC actually exists
  mock_outputs = {
    vpc_id     = "vpc-00000000000000000"
    subnet_ids = ["subnet-00000000", "subnet-11111111"]
  }
}
