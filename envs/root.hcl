# Root Terragrunt Configuration
# This tells Terragrunt: "No matter where I am, put the cache in C:/temp/tg"
download_dir = "C:/temp/tg"

locals {
  # Automatically load environment-level variables
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  tf_provider_vars = local.env_vars.locals.provider_versions

  # Extract the variables for easier use in this file
  environment  = local.env_vars.locals.environment
  aws_region   = local.env_vars.locals.aws_region
  cluster_name = local.env_vars.locals.cluster_name
}

# Generate the provider file dynamically
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF

# Required providers
%{if strcontains(get_terragrunt_dir(), "03-addons")}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> ${local.tf_provider_vars.aws}"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> ${local.tf_provider_vars.helm}"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> ${local.tf_provider_vars.kubernetes}"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= ${local.tf_provider_vars.kubectl}"
    }
  }
}

# Date sources
data "aws_eks_cluster" "cluster" {
  name = "${local.cluster_name}"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "${local.cluster_name}"
}

# Kubernetes dependent providers
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}
%{else}

# Simplified required providers for 01-network and 02-cluster
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> ${local.tf_provider_vars.aws}"
    }
  }
}
%{endif}

# AWS provider (Applied to all modules)
provider "aws" {
  region = "${local.aws_region}"
  default_tags {
    tags = {
      Project     = "EKS-Upgrade-lab-Setup"
      Environment = "sandbox"
      ManagedBy   = "Terraform"
      CostCenter  = "Learning"
    }
  }
}
EOF
}

# remote state configuration Terragrunt will create S3 bucket and sub directories automatically if not present
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket  = "devsecopsguru-terragrunt-state-${get_aws_account_id()}"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = "${local.aws_region}"
    encrypt = true
    # dynamodb_table = "terraform-lock-table"
  }
}

inputs = merge(
  local.env_vars.locals,
  {}
)