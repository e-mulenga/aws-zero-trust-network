terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.27.0, < 7.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Partial backend: bucket, region, encrypt and lockfile come from environments/<env>/backend.hcl,
  # the key is passed by scripts/tf.sh (aws-zero-trust-network/<env>/zerotrust.tfstate).
  backend "s3" {}
}

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = merge(local.tags, { Stack = "zerotrust" })
  }
}
