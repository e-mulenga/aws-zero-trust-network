variable "primary_region" {
  description = "AWS region for the provider and region-scoped resource lookups (e.g. VPC endpoint service names)."
  type        = string
}

variable "firewall_subnet_cidr" {
  description = "CIDR (/28 or larger) of the dedicated firewall subnet. Must sit inside the Landing Zone VPC CIDR and must not overlap any existing subnet (checked at plan time)."
  type        = string
}

variable "inspect_public_subnets" {
  description = "Route all public-subnet internet traffic through Network Firewall. This ADDS routes to Landing Zone-owned route tables (the one deliberate touch of Landing Zone resources) and associates an edge route table with the internet gateway. Needs Landing Zone owner approval."
  type        = bool
  default     = false
}

variable "egress_allowed_domains" {
  description = "Domains the public subnets may reach over TLS. Everything else is dropped. Empty by default: the Landing Zone VPC has no NAT gateway, so private workloads have no internet path."
  type        = list(string)
  default     = []
}

variable "create_workload_endpoints" {
  description = "Create the VPC endpoints this workload needs that the Landing Zone does not already provide"
  type        = bool
  default     = true
}

variable "endpoint_az_count" {
  description = "Availability zones for interface endpoints (1 = cost-optimised dev, 2 = resilient)"
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 2], var.endpoint_az_count)
    error_message = "endpoint_az_count must be 1 or 2."
  }
}

variable "manage_guardduty_eks_audit_logs" {
  description = "Enable the GuardDuty EKS audit-log feature on the Landing Zone's existing detector. OFF by default because the detector is Landing Zone-owned; turn on only with Landing Zone owner approval."
  type        = bool
  default     = false
}

variable "enable_firewall_findings" {
  description = "Import Network Firewall alerts into Security Hub as custom findings. Only effective when the Landing Zone reports security_hub_enabled = true."
  type        = bool
  default     = true
}

variable "manage_session_preferences" {
  description = "Manage the account-level Session Manager preferences document (SSM-SessionManagerRunShell). Account singleton: disable if the Landing Zone owns it."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention for workload log groups"
  type        = number
  default     = 7
}

variable "session_log_retention_days" {
  description = "Days before Session Manager recordings expire"
  type        = number
  default     = 365
}

variable "monthly_budget_usd" {
  description = "Workload monthly cost budget (USD). 0 disables."
  type        = number
  default     = 0
}

variable "budget_emails" {
  description = "Budget notification recipients. Supply at apply time; never commit addresses."
  type        = list(string)
  default     = []
}

variable "enable_deletion_protection" {
  description = "Firewall delete protection and bucket force_destroy off (required in prod)"
  type        = bool
  default     = false
}

variable "engineer_trusted_principal_arns" {
  description = "Principals allowed to assume the break-glass engineer role (with fresh MFA). Empty creates no role."
  type        = list(string)
  default     = []
}

variable "engineer_session_seconds" {
  description = "Maximum session length of the engineer role"
  type        = number
  default     = 3600

  validation {
    condition     = var.engineer_session_seconds >= 3600 && var.engineer_session_seconds <= 43200
    error_message = "IAM requires a maximum session between 3600 and 43200 seconds."
  }
}

variable "create_tier_security_groups" {
  description = "Create web, app and db tier security groups in the Landing Zone VPC (security-group-to-security-group rules only)"
  type        = bool
  default     = false
}

variable "tier_app_port" {
  description = "Port the web tier may reach on the app tier"
  type        = number
  default     = 8080
}

variable "tier_db_port" {
  description = "Port the app tier may reach on the database tier"
  type        = number
  default     = 5432
}

variable "enable_point_in_time_recovery" {
  type    = bool
  default = false
}

variable "enable_dynamodb_replication" {
  type    = bool
  default = false
}

variable "primary_region" {
  description = "AWS region for the provider and region-scoped resource lookups (e.g. VPC endpoint service names)."
  type        = string
}
