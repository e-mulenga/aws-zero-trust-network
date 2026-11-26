variable "enable_dynamodb_replication" {
  description = "Replicate the three tables to the DR region (Ireland) as DynamoDB global tables. With CMKs this needs a DR replica key from the Landing Zone (shared_kms_keys[domain].replica_arn)."
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Protect tables against deletion (required in prod)"
  type        = bool
  default     = false
}

variable "enable_point_in_time_recovery" {
  description = "Continuous backups for the tables"
  type        = bool
  default     = true
}
