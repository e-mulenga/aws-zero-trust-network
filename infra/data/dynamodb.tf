resource "aws_dynamodb_table" "wallets" {
  name         = "${local.name_prefix}-wallets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "wallet_id"

  attribute {
    name = "wallet_id"
    type = "S"
  }

  # Global-table replicas require streams (NEW_AND_OLD_IMAGES).
  stream_enabled   = var.enable_dynamodb_replication
  stream_view_type = var.enable_dynamodb_replication ? "NEW_AND_OLD_IMAGES" : null

  deletion_protection_enabled = var.enable_deletion_protection

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # AWS-owned/managed encryption in dev; Landing Zone CMK when the key strategy is CMK.
  dynamic "server_side_encryption" {
    for_each = local.kms_arn["dynamodb"] == null ? [] : [1]
    content {
      enabled     = true
      kms_key_arn = local.kms_arn["dynamodb"]
    }
  }

  dynamic "replica" {
    for_each = var.enable_dynamodb_replication ? [1] : []
    content {
      region_name = var.dr_region
      kms_key_arn = local.use_cmk ? try(local.shared_kms_keys[var.kms_key_domains["dynamodb"]].replica_arn, null) : null
    }
  }

  tags = {
    Workload = local.name_prefix
  }
}

resource "aws_dynamodb_table" "transactions" {
  name         = "${local.name_prefix}-transactions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "transaction_id"

  attribute {
    name = "transaction_id"
    type = "S"
  }

  attribute {
    name = "idempotency_key"
    type = "S"
  }

  global_secondary_index {
    name            = "idempotency_key-index"
    hash_key        = "idempotency_key"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  deletion_protection_enabled = var.enable_deletion_protection

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # AWS-owned/managed encryption in dev; Landing Zone CMK when the key strategy is CMK.
  dynamic "server_side_encryption" {
    for_each = local.kms_arn["dynamodb"] == null ? [] : [1]
    content {
      enabled     = true
      kms_key_arn = local.kms_arn["dynamodb"]
    }
  }

  dynamic "replica" {
    for_each = var.enable_dynamodb_replication ? [1] : []
    content {
      region_name = var.dr_region
      kms_key_arn = local.use_cmk ? try(local.shared_kms_keys[var.kms_key_domains["dynamodb"]].replica_arn, null) : null
    }
  }

  tags = {
    Workload = local.name_prefix
  }
}

resource "aws_dynamodb_table" "fraud_events" {
  name         = "${local.name_prefix}-fraud-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  # Global-table replicas require streams (NEW_AND_OLD_IMAGES).
  stream_enabled   = var.enable_dynamodb_replication
  stream_view_type = var.enable_dynamodb_replication ? "NEW_AND_OLD_IMAGES" : null

  deletion_protection_enabled = var.enable_deletion_protection

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # AWS-owned/managed encryption in dev; Landing Zone CMK when the key strategy is CMK.
  dynamic "server_side_encryption" {
    for_each = local.kms_arn["dynamodb"] == null ? [] : [1]
    content {
      enabled     = true
      kms_key_arn = local.kms_arn["dynamodb"]
    }
  }

  dynamic "replica" {
    for_each = var.enable_dynamodb_replication ? [1] : []
    content {
      region_name = var.dr_region
      kms_key_arn = local.use_cmk ? try(local.shared_kms_keys[var.kms_key_domains["dynamodb"]].replica_arn, null) : null
    }
  }

  tags = {
    Workload = local.name_prefix
  }
}
