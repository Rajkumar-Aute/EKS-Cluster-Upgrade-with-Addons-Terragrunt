include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "cluster" {
  config_path = "../02-cluster"
  
  # Ensure Addons wait if the cluster isn't fully ready
  mock_outputs = {
    cluster_name = "mock-cluster"
    cluster_endpoint = "https://mock.endpoint"
    cluster_certificate_authority_data = "bW9jaw=="
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/mock"
    karpenter_iam_role_arn = "arn:aws:iam::123456789012:role/mock"
    karpenter_queue_name = "mock-queue"
  }
}

inputs = {
  cluster_name                       = dependency.cluster.outputs.cluster_name
  cluster_endpoint                   = dependency.cluster.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.cluster.outputs.cluster_certificate_authority_data
  oidc_provider_arn                  = dependency.cluster.outputs.oidc_provider_arn
  route53_zone_id                    = dependency.network.outputs.subdomain_zone_id
  oidc_provider_arn                  = dependency.cluster.outputs.oidc_provider_arn
  karpenter_iam_role_arn             = dependency.cluster.outputs.karpenter_iam_role_arn
  karpenter_queue_name               = dependency.cluster.outputs.karpenter_queue_name
}