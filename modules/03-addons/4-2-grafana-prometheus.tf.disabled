##### Kube-Prometheus-Stack starts here ##### 
# Install the Kube-Prometheus-Stack (Prometheus, Grafana, Alertmanager)
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = var.kube_prometheus_stack_version

  atomic          = true
  cleanup_on_fail = true
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 600
  wait            = true
  wait_for_jobs   = true

  # We use 'values' to set a default Grafana password and 
  # bypass the need for the AWS EBS CSI Driver in this lab.
  values = [
    yamlencode({
      grafana = {
        adminPassword = "admin"
        service = {
          type = "ClusterIP"
          # type: LoadBalancer
          #   annotations:
          #     # This tells the AWS LB Controller to create an internet-facing balancer
          #     service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
          #     # Optional: Use an NLB
          #     service.beta.kubernetes.io/aws-load-balancer-type: "external"
          #     service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
        }
      }

      # Keep these as null to avoid needing EBS CSI driver (Ephemeral storage)
      prometheus = {
        prometheusSpec = {
          storageSpec = null
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          storage = null
        }
      }
    })
  ]
}

##### Kube-Prometheus-Stack ends here #####