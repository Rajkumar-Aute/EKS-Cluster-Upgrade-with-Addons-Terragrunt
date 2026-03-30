##### Trivy Operator starts here #####

# install trivy operator

resource "helm_release" "trivy_operator" {
  name             = "trivy-operator"
  repository       = "https://aquasecurity.github.io/helm-charts/"
  chart            = "trivy-operator"
  namespace        = "trivy-system"
  create_namespace = true
  version          = var.trivy_operator_version

  atomic          = true
  cleanup_on_fail = true
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 600
  wait            = true
  wait_for_jobs   = true

  # We use 'values' to tune the operator for a cleaner experience.
  # 'ignoreUnfixed' prevents Trivy from yelling about vulnerabilities 
  # that don't even have a patch available from the vendor yet.

  values = [
    <<-EOT
    trivy:
      ignoreUnfixed: true
    operator:
      scannerReportTTL: "24h" # Automatically delete old scan reports after 24 hours
    EOT
  ]
}

##### Trivy Operator ends here #####