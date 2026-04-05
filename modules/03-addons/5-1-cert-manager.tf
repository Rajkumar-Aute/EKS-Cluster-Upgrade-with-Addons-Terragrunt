##### cert-manager starts here #####
# Cert-manager is a Kubernetes add-on that automates the management and issuance of TLS certificates from various issuing sources. It helps secure your applications by ensuring they have valid TLS certificates, which are essential for encrypted communication.

# Install the cert-manager using Helm Chart
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = var.cert_manager_version


  atomic          = true
  cleanup_on_fail = true
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 600
  wait            = true
  wait_for_jobs   = true

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
        email  = "admin@devsecopsguru.in"
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
