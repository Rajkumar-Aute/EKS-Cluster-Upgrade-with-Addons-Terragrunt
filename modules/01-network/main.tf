# For cost-effective testing and learning, this Terraform configuration creates an EKS cluster in the default VPC of your AWS account.
# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch the subnets associated with the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Fetch the specific details of each subnet so we can read their AZs
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Filter out the unsupported subnet
locals {
  supported_subnets = [
    for s in data.aws_subnet.default : s.id
    if s.availability_zone != "${var.aws_region}e"
  ]
}

