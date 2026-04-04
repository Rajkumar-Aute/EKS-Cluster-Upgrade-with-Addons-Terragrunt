# Important file to include for Terragrunt to work with Terraform code.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# This terraform module need need some inputs to mapping with other modules details.
dependency "network" {
  config_path = "../01-network"
}


# Pass the outputs from Network directly into the Cluster variables
inputs = {
  vpc_id     = dependency.network.outputs.vpc_id
  subnet_ids = dependency.network.outputs.subnet_ids
}
