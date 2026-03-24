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

# Karpenter requires subnets to be tagged so it knows where to launch nodes.
resource "aws_ec2_tag" "karpenter_subnets" {
  for_each    = toset(local.supported_subnets)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}


# AWS LOAD BALANCER CONTROLLER: SUBNET DISCOVERY TAGS
# -------------------------------------------------------------
# The AWS LBC requires this specific tag on public subnets to 
# know where it is allowed to provision internet-facing load balancers.
resource "aws_ec2_tag" "public_subnet_lb_tags" {
  for_each    = toset(local.supported_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

