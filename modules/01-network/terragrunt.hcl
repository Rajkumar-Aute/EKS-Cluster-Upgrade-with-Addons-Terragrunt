# Important file to include for Terragrunt to work with Terraform code.
include "root" {
  path = find_in_parent_folders("root.hcl")
}
