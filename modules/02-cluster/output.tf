output "cluster_name" {
  value = module.eks.cluster_name # 
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint # 
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "karpenter_iam_role_arn" {
  value = module.karpenter.iam_role_arn
}

output "karpenter_queue_name" {
  value = module.karpenter.queue_name
}

output "eksctl_to_get_kubeconfig" {
  value =  "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"  
}