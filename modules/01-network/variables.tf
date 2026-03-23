variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
}

variable "cluster_certificate_authority_data" {
  type    = string
  default = ""
}

variable "domain_name" {
  description = "The domain name to use for the cluster (e.g., eks.devsecopsguru.in)"
  type        = string
}