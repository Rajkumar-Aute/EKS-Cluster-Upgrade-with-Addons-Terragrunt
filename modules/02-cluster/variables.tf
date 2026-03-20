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
  description = "The minimum number of nodes for the EKS cluster"
  type        = number
}

variable "max_node_groups_nodes" {
  description = "The maximum number of nodes for the EKS cluster"
  type        = number
}

variable "desired_node_groups_nodes" {
  description = "The desired number of nodes for the EKS cluster"
  type        = number
}