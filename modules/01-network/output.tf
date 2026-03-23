output "vpc_id" {
  description = "The ID of the VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "The IDs of the supported subnets"
  value       = local.supported_subnets
}

# output "subnet_zone_id" {
#   description = "Mapping of subnet IDs to their availability zones"
#   value       = aws_route53_zone.subdomain.zone_id
# }