##### External Secrets Operator starts here #####

# IAM role for external secrets operator
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

# Install the external secrets helm chart
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = var.external_secrets_version

  atomic          = true
  cleanup_on_fail = true
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 600
  wait            = true
  wait_for_jobs   = true

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

}


# configure the aws cluster secret store

# the secret store
resource "kubectl_manifest" "aws_cluster_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = "us-east-1"
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  })

  # This is the secret sauce for automation: 
  # It waits for Helm to finish, but doesn't crash during 'plan'
  depends_on = [helm_release.external_secrets]
}


# the ssm store

resource "kubectl_manifest" "aws_ssm_parameter_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-ssm-parameter-store"
    }
    spec = {
      provider = {
        aws = {
          service = "ParameterStore"
          region  = "us-east-1"
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [helm_release.external_secrets]
}


#### External Secrets Operator ends here #####


