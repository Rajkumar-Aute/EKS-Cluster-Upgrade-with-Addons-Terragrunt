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

variable "vpc_id" {
  description = "The ID of the VPC to deploy the EKS cluster in"
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs to deploy the EKS cluster in"
  type        = list(string)
}

variable "min_node_groups_nodes" {
  description = "The minimum number of worker nodes for the EKS cluster"
  type        = number
  default = 1
}

variable "max_node_groups_nodes" {
  description = "The maximum number of worker nodes for the EKS cluster"
  type        = number
  default = 3
}

variable "desired_node_groups_nodes" {
  description = "The desired number of worker nodes for the EKS cluster"
  type        = number
  default = 2
}

variable "eks_capacity_type" {
  description = "The capacity type for the EKS node group (e.g., ON_DEMAND or SPOT)"
  type        = string
  default     = "SPOT"
}

variable "eks_instance_types" {
  description = "A list of EC2 instance types for the EKS node group"
  type        = list(string)
}