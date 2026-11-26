# ============================================================
# Landing Zone consumption (source of truth).
# This stack never creates VPCs, subnets, route tables for the VPC, NAT, ECR repositories,
# KMS keys, GuardDuty detectors, Security Hub, Config, CloudTrail, Access Analyzer, flow logs, state buckets or OIDC providers.
# ============================================================

variable "landing_zone_state_bucket" {
  description = "S3 bucket holding the Landing Zone Terraform state"
  type        = string
}

variable "landing_zone_state_key" {
  description = "S3 key of the Landing Zone Terraform state"
  type        = string
}

variable "landing_zone_state_region" {
  description = "Region of the Landing Zone state bucket"
  type        = string
}

variable "expected_landing_zone_contract_version" {
  description = "Landing Zone contract_schema_version this stack was written against"
  type        = string
  default     = "2"
}

variable "environment" {
  description = "dev, test or prod"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "primary_region" {
  description = "Primary region (Cape Town)"
  type        = string
  default     = "af-south-1"

  validation {
    condition     = var.primary_region == "af-south-1"
    error_message = "Approved primary region is af-south-1."
  }
}

variable "dr_region" {
  description = "Disaster recovery region (Ireland). Also where services unavailable in af-south-1 are deployed."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = var.dr_region == "eu-west-1"
    error_message = "Approved DR region is eu-west-1."
  }
}

data "terraform_remote_state" "landing_zone" {
  backend = "s3"

  config = {
    bucket  = var.landing_zone_state_bucket
    key     = var.landing_zone_state_key
    region  = var.landing_zone_state_region
    encrypt = true
  }
}

locals {
  lz = data.terraform_remote_state.landing_zone.outputs

  lz_primary = local.lz.af_south_1
  lz_dr      = local.lz.eu_west_1

  vpc_id             = local.lz_primary.vpc_id
  vpc_cidr           = local.lz_primary.vpc_cidr_block
  azs                = local.lz_primary.azs
  public_subnet_ids  = local.lz_primary.public_subnet_ids
  private_subnet_ids = local.lz_primary.private_subnet_ids

  key_strategy    = local.lz.key_strategy
  use_cmk         = local.key_strategy != "aws-managed"
  shared_kms_keys = local.lz.shared_kms_keys

  # Shared ECR repositories (the repository for application images is shared-applications)
  shared_ecr_urls = local.lz.ecr_repository_urls

  security_hub_enabled = try(local.lz.security_hub_enabled, false)
  access_analyzer_arn  = try(local.lz.access_analyzer_arn, null)

  name_prefix = "${var.workload_name}-${var.environment}"

  tags = {
    Project     = "aws-zero-trust-network"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }

  kms_arn = {
    for purpose, domain in var.kms_key_domains :
    purpose => local.use_cmk ? try(local.shared_kms_keys[domain].arn, null) : null
  }
}

variable "workload_name" {
  description = "Workload name prefix"
  type        = string
  default     = "payment-platform"
}

variable "require_cmk" {
  description = "Fail the plan unless the Landing Zone provides customer-managed keys. Set true in prod where governance requires it; dev and test use AWS-managed keys."
  type        = bool
  default     = false
}

variable "owner" {
  description = "Owning team (tag)"
  type        = string
}

variable "cost_center" {
  description = "Cost centre (tag)"
  type        = string
}

variable "kms_key_domains" {
  description = "Purpose => Landing Zone shared_kms_keys domain. Used only when the Landing Zone key_strategy is not aws-managed. The Landing Zone exports ai, analytics, backup, rds and s3 slots; the eks purpose maps to a slot of your choice (default eks) and must be exported before a CMK is used for it."
  type        = map(string)
  default = {
    eks         = "eks"
    dynamodb    = "rds"
    sqs         = "rds"
    session_log = "s3"
  }
}

# ---- Guardrails: fail the plan when the Landing Zone does not fit ----
resource "terraform_data" "landing_zone_contract" {
  lifecycle {
    precondition {
      condition     = local.lz.contract_schema_version == var.expected_landing_zone_contract_version
      error_message = "Landing Zone contract_schema_version is '${local.lz.contract_schema_version}', expected '${var.expected_landing_zone_contract_version}'."
    }
    precondition {
      condition     = local.lz_primary.region == var.primary_region && local.lz_dr.region == var.dr_region
      error_message = "Landing Zone regions do not match primary_region/dr_region."
    }
    precondition {
      condition     = !var.require_cmk || local.use_cmk
      error_message = "require_cmk is true, but the Landing Zone key_strategy is 'aws-managed'. This repo never creates keys: extend the Landing Zone export."
    }
    precondition {
      condition     = !local.use_cmk || alltrue([for p in keys(var.kms_key_domains) : local.kms_arn[p] != null])
      error_message = "key_strategy is CMK but shared_kms_keys lacks an arn for a mapped domain (see var.kms_key_domains)."
    }
    precondition {
      condition     = contains(keys(local.shared_ecr_urls), "shared-applications")
      error_message = "Landing Zone does not export the shared-applications ECR repository."
    }
  }
}
