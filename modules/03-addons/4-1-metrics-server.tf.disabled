##### Metrics Server starts here #####
# Install the Kubernetes Metrics Server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_server_version

  atomic          = true
  cleanup_on_fail = true
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 600
  wait            = true
  wait_for_jobs   = true



  # We use 'values' here to pass raw YAML. 
  # EKS sometimes struggles with self-signed Kubelet certificates 
  # out of the box, so we tell Metrics Server to bypass strict TLS 
  # validation for internal node communication.

  values = [
    <<-EOT
    defaultArgs:
      - --cert-dir=/tmp
      - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
      - --kubelet-use-node-status-port
      - --metric-resolution=15s
      - --kubelet-insecure-tls
    EOT
  ]
}

##### Metrics Server ends here #####


