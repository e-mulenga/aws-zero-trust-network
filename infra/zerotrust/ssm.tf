# Administrative access through Session Manager only: no SSH key, no bastion, no inbound admin rule.
# Sessions are recorded to a workload-owned bucket in the primary region. (The Landing Zone log
# buckets are in us-east-1 and shared; session recordings stay in af-south-1.)

data "aws_eks_node_groups" "workload" {
  cluster_name = data.aws_eks_cluster.workload.name
}

data "aws_eks_node_group" "workload" {
  for_each = data.aws_eks_node_groups.workload.names

  cluster_name    = data.aws_eks_cluster.workload.name
  node_group_name = each.value
}

locals {
  node_role_names = toset([
    for ng in data.aws_eks_node_group.workload : element(split("/", ng.node_role_arn), length(split("/", ng.node_role_arn)) - 1)
  ])

  session_cmk = local.use_cmk ? local.kms_arn["session_log"] : null
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  for_each = local.node_role_names

  role       = each.value
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_s3_bucket" "session_logs" {
  bucket_prefix = "${local.name_prefix}-sessions-"
  force_destroy = !var.enable_deletion_protection
}

resource "aws_s3_bucket_public_access_block" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# dev/test: SSE-S3 (AWS managed). CMK in use: the Landing Zone key (the precondition guarantees it exists).
resource "aws_s3_bucket_server_side_encryption_configuration" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id

  rule {
    bucket_key_enabled = local.session_cmk != null
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.session_cmk != null ? "aws:kms" : "AES256"
      kms_master_key_id = local.session_cmk
    }
  }
}

resource "aws_s3_bucket_versioning" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id

  versioning_configuration {
    status = var.environment == "prod" ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id

  rule {
    id     = "expire-recordings"
    status = "Enabled"
    filter {}

    expiration {
      days = var.session_log_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "session_logs_bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.session_logs.arn, "${aws_s3_bucket.session_logs.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id
  policy = data.aws_iam_policy_document.session_logs_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.session_logs]
}

data "aws_iam_policy_document" "node_session_logs" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.session_logs.arn}/sessions/*"]
  }

  statement {
    actions   = ["s3:GetEncryptionConfiguration"]
    resources = [aws_s3_bucket.session_logs.arn]
  }

  dynamic "statement" {
    for_each = local.session_cmk != null ? [1] : []
    content {
      actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
      resources = [local.session_cmk]
    }
  }
}

resource "aws_iam_role_policy" "node_session_logs" {
  for_each = local.node_role_names

  name   = "write-session-logs"
  role   = each.value
  policy = data.aws_iam_policy_document.node_session_logs.json
}

# Account-level Session Manager preferences (singleton): every shell session is recorded.
resource "aws_ssm_document" "session_preferences" {
  count = var.manage_session_preferences ? 1 : 0

  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferences: sessions recorded to S3, encrypted transport, idle timeout"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName           = aws_s3_bucket.session_logs.id
      s3KeyPrefix            = "sessions"
      s3EncryptionEnabled    = true
      cloudWatchLogGroupName = ""
      kmsKeyId               = ""
      runAsEnabled           = false
      idleSessionTimeout     = "20"
      shellProfile = {
        linux = "cd /tmp && echo \"Recorded session on $(hostname) at $(date -u +%FT%TZ)\""
      }
    }
  })
}
