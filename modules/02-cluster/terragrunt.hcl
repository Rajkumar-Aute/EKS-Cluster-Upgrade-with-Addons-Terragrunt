include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "network" {
  config_path = "../01-network"
}


# Pass the outputs from Network directly into the Cluster variables
inputs = {
  vpc_id     = dependency.network.outputs.vpc_id
  subnet_ids = dependency.network.outputs.subnet_ids
}