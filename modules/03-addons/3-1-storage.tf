
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
  cluster_name = var.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  # Check addon_version            = var.ebs_csi_version
  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
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