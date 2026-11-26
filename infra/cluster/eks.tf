locals {
  cluster_name = "${local.name_prefix}-eks"
}

# Additive discovery tags on Landing Zone subnets (the subnets themselves are never created here).
resource "aws_ec2_tag" "public_elb" {
  for_each    = var.tag_landing_zone_subnets ? toset(local.public_subnet_ids) : toset([])
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_internal_elb" {
  for_each    = var.tag_landing_zone_subnets ? toset(local.private_subnet_ids) : toset([])
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "cluster_shared" {
  for_each    = var.tag_landing_zone_subnets ? toset(concat(local.public_subnet_ids, local.private_subnet_ids)) : toset([])
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.cluster_name
  kubernetes_version = var.cluster_version

  # Landing Zone network (consumed, not created)
  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  endpoint_public_access  = !var.zero_trust_private_api
  endpoint_private_access = true

  enable_irsa = true

  # Secrets envelope encryption: AWS-managed by default (no KMS key created); the Landing Zone CMK
  # when key_strategy provides one (never a key created in this repository).
  create_kms_key = false
  encryption_config = local.kms_arn["eks"] == null ? null : {
    resources        = ["secrets"]
    provider_key_arn = local.kms_arn["eks"]
  }

  eks_managed_node_groups = {
    default = {
      min_size     = 2
      max_size     = 3
      desired_size = var.node_desired_size

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "general"
      }
    }
  }

  node_security_group_additional_rules = {
    ingress_istio_webhook = {
      description                   = "Cluster API Server to Istio webhook (istiod)"
      protocol                      = "tcp"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  enable_cluster_creator_admin_permissions = true

  depends_on = [terraform_data.landing_zone_contract]
}
