output "vpc_id" {
  description = "The ID of the Default VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "The IDs of the supported subnets"
  value       = local.supported_subnets
}
