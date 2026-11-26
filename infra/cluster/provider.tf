terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.27.0, < 7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }

  # Partial backend: bucket, region, encrypt and lockfile come from environments/<env>/backend.hcl,
  # the key is passed by scripts/tf.sh (aws-zero-trust-network/<env>/cluster.tfstate).
  backend "s3" {}
}

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = merge(local.tags, { Stack = "cluster" })
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.primary_region]
  }
}
