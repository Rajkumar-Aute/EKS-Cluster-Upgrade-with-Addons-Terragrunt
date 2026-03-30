variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "The API endpoint of the EKS cluster"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "The base64-encoded certificate authority data for the EKS cluster"
  type        = string
}
variable "oidc_provider_arn" {
  description = "The ARN of the OIDC provider for the EKS cluster"
  type        = string
}


# Addon versions
variable "karpenter_version" {
  description = "Helm chart version for Karpenter"
  type        = string
}

variable "keda_version" {
  description = "Helm chart version for KEDA"
  type        = string
}

variable "cert_manager_version" {
  description = "Helm chart version for cert-manager"
  type        = string
}

variable "nginx_ingress_version" {
  description = "Helm chart version for NGINX Ingress Controller"
  type        = string
}

variable "external_dns_version" {
  description = "Helm chart version for ExternalDNS"
  type        = string
}

variable "external_secrets_version" {
  description = "Helm chart version for External Secrets Operator"
  type        = string
}

variable "kyverno_version" {
  description = "Helm chart version for Kyverno and Kyverno Policies"
  type        = string
}

variable "trivy_operator_version" {
  description = "Helm chart version for Trivy Operator"
  type        = string
}

variable "metrics_server_version" {
  description = "Helm chart version for Metrics Server"
  type        = string
}

variable "kube_prometheus_stack_version" {
  description = "Helm chart version for Kube-Prometheus-Stack"
  type        = string
}

