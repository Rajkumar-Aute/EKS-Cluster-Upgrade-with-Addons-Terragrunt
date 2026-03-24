# Provision the EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }

  # create_cloudwatch_log_group = true  
  # cloudwatch_log_group_retention_in_days = 1   # Optional: Set a short retention to save costs

  create_cloudwatch_log_group = false
  create_kms_key              = false
  cluster_enabled_log_types = []
  
  # Tell EKS not to use managed encryption for now
  cluster_encryption_config = {}



  # Allow public access to the Kubernetes API server
  cluster_endpoint_public_access = true

  # Attach the cluster to the default VPC and its subnets
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Automatically grant cluster admin permissions to the IAM user/role running this Terraform
  enable_cluster_creator_admin_permissions = true

  # Karpenter needs to discover the node security group to attach to new nodes
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  # Configure Managed Node Groups
  eks_managed_node_groups = {
    spot_node_group = {
      # General configuration      
      name            = "${var.cluster_name}-spot"
      description     = "A EKS Upgrade Practice spot node group"
      use_name_prefix = true # If true, Terraform appends random characters to the name

      # Capacity and OS Settings
      capacity_type  = "SPOT"                      # Can be "ON_DEMAND" or "SPOT"
      instance_types = ["t3.large", "t3a.large"] # Multiple types protect against Spot shortages

      # AL2023 is the new standard. Other options include AL2_x86_64, BOTTLEROCKET_x86_64, etc.
      ami_type = "AL2023_x86_64_STANDARD"

      # Scaling (Requires Cluster Autoscaler or Karpenter to work)
      min_size     = var.min_node_groups_nodes     # Absolute minimum number of nodes
      max_size     = var.max_node_groups_nodes     # Maximum number of nodes the autoscaler can spin up
      desired_size = var.desired_node_groups_nodes # The initial target number of nodes to deploy

      # Rolling updates and lifecycle settings
      update_config = {
        # Dictates how many nodes can be down simultaneously during a cluster upgrade.
        # Can be a percentage (max_unavailable_percentage = 33) OR a hard number:
        max_unavailable = 1
      }
      # If pods refuse to drain (e.g., missing PodDisruptionBudgets), force the update anyway
      force_update_version = true

      # Kubernetes scheduling settings (Labels & Taints)
      # Labels allow you to pin specific pods to this node group using nodeSelector
      labels = {
        Environment   = "Learning"
        Lifecycle     = "spot"
        InstanceGroup = "spot-workers"
      }

      # Taints repel pods. Only pods with a matching "toleration" can run here.
      # Useful if you want to keep critical system pods off of volatile Spot instances.
      taints = {
        spot_instances = {
          key    = "spotInstance"
          value  = "true"
          effect = "PREFER_NO_SCHEDULE" # Or "NO_SCHEDULE" for a strict block
        }
      }

      # Storage settings for the EC2 instances in this node group. This example configures the root EBS volume, but you can also add additional block devices if needed.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 50    # Size in GB
            volume_type = "gp3" # gp3 is faster and cheaper than gp2
            iops        = 3000
            throughput  = 125
            encrypted   = true
            # kms_key_id          = "arn:aws:kms:region:account:key/..." # Optional custom KMS key
            delete_on_termination = true
          }
        }
      }

      # Networking & Security settings for the EC2 instances in this node group
      # By default, nodes use the subnets defined at the cluster level. 
      # Uncomment this to force nodes into specific subnets:
      # subnet_ids = ["subnet-xyz123", "subnet-abc456"]

      # Attach extra Security Groups to your nodes (e.g., to allow RDS database access)
      # vpc_security_group_ids = ["sg-0123456789abcdef0"]

      # Allow SSH access (Requires an SG that permits port 22)
      # key_name = "my-aws-ssh-key-name"


      # IAM (Identity & Access Management)
      iam_role_name            = "spot-node-group-role"
      iam_role_use_name_prefix = true # If true, Terraform appends random characters to the name to ensure uniqueness

      # Attach extra IAM policies to your EC2 nodes. 
      # (e.g., giving nodes the ability to pull from S3 or use SSM Session Manager)
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # EC2 Metadata Service (IMDS) settings for the nodes in this group.
      # Enforcing IMDSv2 helps prevent SSRF attacks on your pods
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required" # "required" enforces IMDSv2
        http_put_response_hop_limit = 2
      }
    }
  }
}
