
##### Karpenter starts here #####
# Retrieve the authentication token to pull the Karpenter image from AWS Public ECR










data "aws_ecrpublic_authorization_token" "token" {}

# Install the Karpenter Helm Chart
resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_version

  values = [
    <<-EOT
    serviceAccount:
      annotations:
        # Attaches the IRSA IAM role we created earlier to the pod
        eks.amazonaws.com/role-arn: ${var.karpenter_iam_role_arn}
    settings:
      # Tells Karpenter which cluster it is managing
      clusterName: ${var.cluster_name}
      # Tells Karpenter which SQS queue to listen to for Spot interruptions
      interruptionQueue: ${var.karpenter_queue_name}
    EOT
  ]
}



# KARPENTER EC2 NODE CLASS (The "Where" and "How")
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = { name = "default" }
    spec = {
      amiFamily = "AL2023"
      amiSelectorTerms = [{ alias = "al2023@latest" }]
      role      = "${var.cluster_name}-karpenter-node"
      subnetSelectorTerms = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
      securityGroupSelectorTerms = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
    }
  })
  # This dependency now works perfectly!
  depends_on = [helm_release.karpenter] 
}
# -------------------------------------------------------------
# 2. KARPENTER NODE POOL (The "What" and "How Much")
# -------------------------------------------------------------
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            # Only use Spot instances for cost savings
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
            # Allow t3, m5, and c5 instance families
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["t3", "m5", "c5"] }
          ]
        }
      }
      # Hard limit to protect your AWS bill
      limits = {
        cpu = "100"
      }
      # Consolidation: Karpenter will constantly try to pack pods tightly and delete empty nodes
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
      
    }
  })

  depends_on = [kubectl_manifest.karpenter_node_class]
}

##### Karpenter ends here #####


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

# Storage Classes

##### Storage Classes start here #####
# IAM ROLE FOR THE EBS CSI DRIVER
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}


# INSTALL THE EBS CSI DRIVER ADD-ON
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn

  resolve_conflicts_on_update = "PRESERVE"
  resolve_conflicts_on_create = "OVERWRITE"
}




# PATCH GP2 TO REMOVE DEFAULT STATUS

resource "kubernetes_annotations" "disable_gp2_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = true 

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  # This dependency will now successfully find the addon resource above!
  depends_on = [aws_eks_addon.ebs_csi_driver] 
}


# CREATE GP3 AND MAKE IT DEFAULT

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  reclaim_policy      = "Delete"

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

##### Storage Classes end here #####



###### Traffic Management (Ingress & DNS)

##### NGINX Ingress Controller starts here #####
# Install NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = var.nginx_ingress_version


  # The magic happens in these annotations. They tell the AWS Load 
  # Balancer Controller to build a single, high-performance Network 
  # Load Balancer (NLB) to sit in front of NGINX.
  # -------------------------------------------------------------
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



##### AWS Load Balancer Controller start here #####

# Create the IAM Role and Policy for the Load Balancer Controller
module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "${var.cluster_name}-aws-lbc"

  # This boolean tells the module to attach the official AWS Load Balancer Controller IAM policy
  attach_load_balancer_controller_policy = true

  # Tie the IAM role securely to the specific Kubernetes ServiceAccount in the kube-system namespace
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# 2. Install the AWS Load Balancer Controller Helm Chart
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_lbc_version

  # Pass the cluster name and the newly created IAM role ARN to the Helm chart
  values = [
    <<-EOT
    clusterName: ${var.cluster_name}
    serviceAccount:
      create: true
      name: aws-load-balancer-controller
      annotations:
        eks.amazonaws.com/role-arn: ${module.aws_load_balancer_controller_irsa_role.iam_role_arn}
    EOT
  ]
}


##### AWS Load Balancer Controller ends here #####


##### ExternalDNS starts here #####
# 1. Create the IAM Role and Policy for ExternalDNS
module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "${var.cluster_name}-external-dns"

  # This built-in flag automatically attaches the AWS-managed policy for Route53 access
  attach_external_dns_policy = true

  # Tie the IAM role securely to the specific Kubernetes ServiceAccount
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

# 2. Install the ExternalDNS Helm Chart
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = var.external_dns_version

  values = [
    <<-EOT
    provider: aws
    registry: txt
    txtOwnerId: ${var.cluster_name}
    policy: sync # 'sync' means it will both create and delete records. Use 'upsert-only' if you are nervous about deletions!
    
    # You can restrict ExternalDNS to only manage specific domains so it doesn't touch other Route53 records
    domainFilters:
      - devsecopsguru.in 
      
    serviceAccount:
      create: true
      name: external-dns
      annotations:
        eks.amazonaws.com/role-arn: ${module.external_dns_irsa_role.iam_role_arn}
    EOT
  ]
}

##### ExternalDNS ends here #####



# Security & DevSecOps

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
# 1. INSTALL KYVERNO POLICY ENGINE
# -------------------------------------------------------------
resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  namespace        = "kyverno"
  create_namespace = true
  version          = var.kyverno_version
  
  # Give Karpenter 10 minutes to provision nodes
  timeout          = 300 
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

# AUTO-HEALING: Clear stuck Helm locks before applying
# ---------------------------------------------------------
resource "terraform_data" "helm_lock_snowplow" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = <<-EOT
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


  atomic          = true
  cleanup_on_fail = true
  timeout         = 60

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
  timeout          = 600

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
}


##### Trivy Operator ends here #####








# Observability 

##### Metrics Server starts here #####
# Install the Kubernetes Metrics Server
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  version          = var.metrics_server_version

  # -------------------------------------------------------------
  # We use 'values' here to pass raw YAML. 
  # EKS sometimes struggles with self-signed Kubelet certificates 
  # out of the box, so we tell Metrics Server to bypass strict TLS 
  # validation for internal node communication.
  # -------------------------------------------------------------
  values = [
    <<-EOT
    args:
      - --kubelet-insecure-tls
      - --kubelet-preferred-address-types=InternalIP
    EOT
  ]
}

# to validate kubectl top nodes and kubectl top pods work correctly after Metrics Server is installed. If you see metrics, then the installation was successful and the HPA will be able to function properly.
##### Metrics Server ends here #####


##### Kube-Prometheus-Stack starts here ##### 
# Install the Kube-Prometheus-Stack (Prometheus, Grafana, Alertmanager)
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = var.kube_prometheus_stack_version

  # -------------------------------------------------------------
  # We use 'values' to set a default Grafana password and 
  # bypass the need for the AWS EBS CSI Driver in this lab.
  # -------------------------------------------------------------
  values = [
    <<-EOT
    grafana:
      # Set a default password for the 'admin' user
      adminPassword: "prom-operator"
      
    # Disable persistent storage so the pods schedule immediately
    # (In a real production environment, you would install the AWS 
    # EBS CSI Driver and set these to use a StorageClass)
    prometheus:
      prometheusSpec:
        storageSpec: null
    alertmanager:
      alertmanagerSpec:
        storage: null
    EOT
  ]
}

##### Kube-Prometheus-Stack ends here #####