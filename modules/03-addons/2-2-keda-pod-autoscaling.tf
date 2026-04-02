##### KEDA ends here #####
# KEDA (Kubernetes Event-driven Autoscaling)
resource "time_sleep" "wait_for_lbc_for_keda" {
  depends_on      = [helm_release.aws_load_balancer_controller]
  create_duration = "30s"
}

# IAM Role for KEDA Operator (IRSA)
# This allows KEDA to read metrics from AWS (SQS, CloudWatch, etc.)
module "keda_irsa_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.0"
  role_name = "${var.cluster_name}-keda-operator"

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["keda:keda-operator"]
    }
  }

  # Attach read-only policies so KEDA can see your SQS queues or CloudWatch metrics
  role_policy_arns = {
    CloudWatchReadOnlyAccess = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
    AmazonSQSReadOnlyAccess  = "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess"
  }
}

# Install KEDA via Helm
resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  namespace        = "keda"
  create_namespace = true
  version          = var.keda_version

  atomic          = true
  cleanup_on_fail = true
  force_update    = true
  lint            = true
  recreate_pods   = true
  replace         = true
  timeout         = 600
  wait            = true
  wait_for_jobs   = true

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "keda-operator"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.keda_irsa_role.iam_role_arn
        }
      }

      # Operator Settings
      operator = {
        replicaCount = 1
      }
      # # Best practice: Run KEDA on your 'system' node pool in Auto Mode
      # nodeSelector = {
      #   "eks.amazonaws.com/compute-type" = "auto"
      # }
    })
  ]

  depends_on = [
    module.keda_irsa_role,
    helm_release.aws_load_balancer_controller, 
  ]
}

##### KEDA ends here #####
