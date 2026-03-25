# Root Terragrunt Configuration
# This tells Terragrunt: "No matter where I am, put the cache in C:/temp/tg"
download_dir = "C:/temp/tg"

locals {
  # Automatically load environment-level variables
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

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
# 1. REQUIRED PROVIDERS (Must be at the very top of the file)
%{ if strcontains(get_terragrunt_dir(), "03-addons") }
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

# 2. DATA SOURCES (Only for Addons)
data "aws_eks_cluster" "cluster" {
  name = "${local.cluster_name}"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "${local.cluster_name}"
}

# 3. KUBERNETES-DEPENDENT PROVIDERS
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
%{ else }
# Simplified required providers for 01-network and 02-cluster
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
%{ endif }

# 4. AWS PROVIDER (Applied to all modules)
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

# remote state configuration
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "devsecopsguru-terraform-state-${get_aws_account_id()}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "${local.aws_region}"
    encrypt        = true
    # dynamodb_table = "terraform-lock-table"
  }
}


inputs = merge(
  local.env_vars.locals,
  {}
)