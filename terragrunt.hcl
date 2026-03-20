# Root Terragrunt Configuration

# Generate the aws provider for all directories
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "EKS-Upgrade-lab-Setup"
      Environment = "sandbox"
      ManagedBy   = "Terraform"
      CostCenter  = "Learning"
    }
  }
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

provider "kubectl" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}
EOF
}



# GLOBAL VARIABLES (Passed automatically to all child folders)
inputs = {
  aws_region                = "us-east-1"
  cluster_name              = "EKS-upgrade-lab"
  
  # UPGRADE PRACTICE: Change these values to upgrade the stack
  cluster_version           = "1.34"  # Change to 1.35
  
  karpenter_version         = "1.0.1"   # Change to 1.1.1
  cert_manager_version      = "v1.14.4" # Change to v1.15.3
  nginx_ingress_version     = "4.10.1"  # Change to 4.11.2
  aws_lbc_version           = "1.7.2"   # Change to 1.8.1
  external_dns_version      = "1.14.3"  # Change to 1.15.0
  external_secrets_version  = "0.9.13"  # Change to 0.10.4
  kyverno_version           = "3.2.5"   # Change to 3.3.0
  trivy_operator_version    = "0.20.1"  # Change to 0.21.0
  metrics_server_version    = "3.12.1"  # Change to 3.12.2
  kube_prometheus_stack_version = "58.2.2" # Change to 61.3.0
  
  # Node Group Sizing
  min_node_groups_nodes     = 2
  max_node_groups_nodes     = 2
  desired_node_groups_nodes = 2
}