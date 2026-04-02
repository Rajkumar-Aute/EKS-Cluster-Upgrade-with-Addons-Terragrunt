
##### NGINX Ingress Controller starts here #####

# Wait for the AWS Load Balancer Controller to be fully up and running before installing NGINX Ingress Controller
resource "time_sleep" "wait_for_lbc" {
  depends_on      = [helm_release.aws_load_balancer_controller]
  create_duration = "30s"
}

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
      replicaCount: 2
      service:
        loadBalancerClass: "service.k8s.aws/nlb"
        
        annotations:
          # Use the AWS Load Balancer Controller
          service.beta.kubernetes.io/aws-load-balancer-type: "external"          
          service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"          
          service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing" # Public Facing
          service.beta.kubernetes.io/aws-load-balancer-attributes: "load_balancing.cross_zone.enabled=true"          # Recommended for NLB stability

      # Make NGINX the default ingress class
      ingressClassResource:
        name: nginx
        enabled: true
        default: true
        controllerValue: "k8s.io/ingress-nginx"
    EOT
  ]
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}

##### NGINX Ingress Controller ends here #####