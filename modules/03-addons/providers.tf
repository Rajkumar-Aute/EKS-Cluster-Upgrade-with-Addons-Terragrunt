terraform {
  required_providers {
    helm = {
        source = "hashicorp/helm"
        version = ">= 2.12" 
        }
    kubernetes = {
        source = "hashicorp/kubernetes"
        version = ">= 2.27" 
        }
    # ADD THIS NEW PROVIDER
    kubectl = { source = "gavinbunney/kubectl", version = ">= 1.14" }
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


# ADD THE KUBECTL CONFIGURATION
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
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}