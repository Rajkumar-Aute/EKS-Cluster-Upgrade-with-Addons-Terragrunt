# Kubernetes addons are pre built apps that runs on top of the EKS cluster and provide additional functionality.action.


##### cert-manager starts here #####
# Cert-manager is a Kubernetes add-on that automates the management and issuance of TLS certificates from various issuing sources. It helps secure your applications by ensuring they have valid TLS certificates, which are essential for encrypted communication.
# Install the cert-manager Helm Chart
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = var.cert_manager_version


  force_update    = true
  cleanup_on_fail = true
  replace         = true
  atomic          = false
  timeout         = 600

  wait = true

  # CRITICAL SETTING: Install Custom Resource Definitions (CRDs)
  # cert-manager relies on custom Kubernetes objects like 'Certificates' 
  # and 'ClusterIssuers'. This flag tells Helm to install them.
  values = [
    <<-EOT
    installCRDs: true
    webhook:
      timeoutSeconds: 30
    EOT
  ]
}


# configure let's encrypt cluster issuer

resource "kubectl_manifest" "cluster_issuer_letsencrypt_prod" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "admin@devsecopsguru.in" # Update this if you prefer a different alert email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  })
  depends_on = [helm_release.cert_manager]
}

##### cert-manager ends here #####






##### External Secrets Operator starts here #####
# IAM ROLE FOR EXTERNAL SECRETS OPERATOR
module "external_secrets_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "${var.cluster_name}-external-secrets"

  # The module has a built-in policy specifically for ESO!
  # This grants read-only access to AWS Secrets Manager and SSM Parameter Store.
  attach_external_secrets_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}

# INSTALL THE EXTERNAL SECRETS HELM CHART
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = var.external_secrets_version


  # Use values to install CRDs and attach the IAM role we just created
  values = [
    <<-EOT
    installCRDs: true
    serviceAccount:
      create: true
      name: external-secrets
      annotations:
        eks.amazonaws.com/role-arn: ${module.external_secrets_irsa_role.iam_role_arn}
    EOT
  ]
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}


# # CONFIGURE THE AWS CLUSTER SECRET STORE
# Note - This can be enabled on second apply after the Helm chart is installed, or you can uncomment it now. It will fail on the first apply because the ESO CRDs won't exist yet, but it will work on the second apply once the CRDs are in place.

# resource "kubernetes_manifest" "aws_cluster_secret_store" {
#   # The 'manifest' block accepts standard Kubernetes YAML translated into HCL (Terraform's language)
#   manifest = {
#     apiVersion = "external-secrets.io/v1beta1"
#     kind       = "ClusterSecretStore"
#     metadata = {
#       name = "aws-secrets-manager"
#     }
#     spec = {
#       provider = {
#         aws = {
#           service = "SecretsManager"
#           region  = "us-east-1" # Ensure this matches your AWS region
#           auth = {
#             jwt = {
#               serviceAccountRef = {
#                 name      = "external-secrets"
#                 namespace = "external-secrets"
#               }
#             }
#           }
#         }
#       }
#     }
#   }

#   depends_on = [helm_release.external_secrets]
# }


##### External Secrets Operator ends here #####





##### Kyverno Policy Engine starts here #####
# install Kyverion policy engine
# -------------------------------------------------------------
resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  namespace        = "kyverno"
  create_namespace = true
  version          = var.kyverno_version

  # Give Karpenter 10 minutes to provision nodes
  timeout         = 300
  force_update    = true
  cleanup_on_fail = true
  atomic          = true

  values = [
    <<-EOT
    admissionController:
      replicas: 2
    backgroundController:
      replicas: 2
    reportsController:
      replicas: 2
    EOT
  ]
}


resource "terraform_data" "helm_lock_snowplow" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command     = <<-EOT
      kubectl delete secret -l status=pending-upgrade -n kyverno --ignore-not-found
      kubectl delete secret -l status=pending-install -n kyverno --ignore-not-found
    EOT
    interpreter = ["bash", "-c"]
  }
}

# INSTALL DEFAULT POD SECURITY POLICIES
resource "helm_release" "kyverno_policies" {
  name       = "kyverno-policies"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno-policies"
  namespace  = "kyverno"
  version    = var.kyverno_version


  atomic = true

  timeout = 600

  values = [
    <<-EOT
    validationFailureAction: Audit
    EOT
  ]

  depends_on = [
    helm_release.kyverno,
    terraform_data.helm_lock_snowplow
  ]
}


##### Kyverno Policy Engine ends here #####



##### Trivy Operator starts here #####

# INSTALL TRIVY OPERATOR

resource "helm_release" "trivy_operator" {
  name             = "trivy-operator"
  repository       = "https://aquasecurity.github.io/helm-charts/"
  chart            = "trivy-operator"
  namespace        = "trivy-system"
  create_namespace = true
  version          = var.trivy_operator_version

  # Proactively give Karpenter 10 minutes to provision nodes if needed

  timeout = 600

  # -------------------------------------------------------------
  # We use 'values' to tune the operator for a cleaner experience.
  # 'ignoreUnfixed' prevents Trivy from yelling about vulnerabilities 
  # that don't even have a patch available from the vendor yet.
  # -------------------------------------------------------------
  values = [
    <<-EOT
    trivy:
      ignoreUnfixed: true
    operator:
      scannerReportTTL: "24h" # Automatically delete old scan reports after 24 hours
    EOT
  ]
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}


##### Trivy Operator ends here #####