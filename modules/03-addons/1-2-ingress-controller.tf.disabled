
##### NGINX Ingress Controller starts here #####
# Install NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = var.nginx_ingress_version
  
  atomic          = true
  cleanup_on_fail = true
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 600
  wait            = true
  wait_for_jobs   = true

  # The magic happens in these annotations. They tell the AWS Load 
  # Balancer Controller to build a single, high-performance Network 
  # Load Balancer (NLB) to sit in front of NGINX.
  values = [
    <<-EOT
    controller:
      replicaCount: 2 # Run two instances of NGINX for high availability
      service:
        annotations:
          # Use the AWS Load Balancer Controller (external) instead of the legacy in-tree provider
          service.beta.kubernetes.io/aws-load-balancer-type: "external"
          
          # Provision an NLB that routes traffic directly to the pod IP addresses
          service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
          
          # Ensure the load balancer is public
          service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
          
      # Make NGINX the default ingress class for the cluster
      ingressClassResource:
        default: true
    EOT
  ]
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}

##### NGINX Ingress Controller ends here #####