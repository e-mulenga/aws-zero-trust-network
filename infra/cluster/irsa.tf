locals {
  k8s_namespace = "payment-app"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "irsa_trust" {
  for_each = toset(local.service_names)

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.k8s_namespace}:${each.key}-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service_roles" {
  for_each = toset(local.service_names)

  name               = "${local.name_prefix}-${each.key}-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust[each.key].json

  tags = {
    Workload = local.name_prefix
    Service  = each.key
  }
}

resource "aws_iam_role_policy" "wallet" {
  name = "wallet-dynamodb-access"
  role = aws_iam_role.service_roles["wallet"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = "arn:aws:dynamodb:${var.primary_region}:${data.aws_caller_identity.current.account_id}:table/${local.name_prefix}-wallets"
      }
    ]
  })
}

resource "aws_iam_role_policy" "transaction" {
  name = "transaction-access"
  role = aws_iam_role.service_roles["transaction"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = [
          "arn:aws:dynamodb:${var.primary_region}:${data.aws_caller_identity.current.account_id}:table/${local.name_prefix}-transactions",
          "arn:aws:dynamodb:${var.primary_region}:${data.aws_caller_identity.current.account_id}:table/${local.name_prefix}-transactions/index/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = "arn:aws:events:${var.primary_region}:${data.aws_caller_identity.current.account_id}:event-bus/${local.name_prefix}-events"
      }
    ]
  })
}

resource "aws_iam_role_policy" "fraud_detection" {
  name = "fraud-detection-access"
  role = aws_iam_role.service_roles["fraud-detection"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:Query"]
        Resource = "arn:aws:dynamodb:${var.primary_region}:${data.aws_caller_identity.current.account_id}:table/${local.name_prefix}-transactions"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"]
        Resource = "arn:aws:dynamodb:${var.primary_region}:${data.aws_caller_identity.current.account_id}:table/${local.name_prefix}-transactions/stream/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:Scan"]
        Resource = "arn:aws:dynamodb:${var.primary_region}:${data.aws_caller_identity.current.account_id}:table/${local.name_prefix}-fraud-events"
      },
      {
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = "arn:aws:events:${var.primary_region}:${data.aws_caller_identity.current.account_id}:event-bus/${local.name_prefix}-events"
      }
    ]
  })
}

resource "aws_iam_role_policy" "notification" {
  name = "notification-sqs-access"
  role = aws_iam_role.service_roles["notification"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = "arn:aws:sqs:${var.primary_region}:${data.aws_caller_identity.current.account_id}:${local.name_prefix}-notification-queue"
      }
    ]
  })
}

resource "aws_iam_role_policy" "reconciliation" {
  name = "reconciliation-access"
  role = aws_iam_role.service_roles["reconciliation"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:Scan", "dynamodb:GetItem"]
        Resource = "arn:aws:dynamodb:${var.primary_region}:${data.aws_caller_identity.current.account_id}:table/${local.name_prefix}-wallets"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = "arn:aws:sqs:${var.primary_region}:${data.aws_caller_identity.current.account_id}:${local.name_prefix}-reconciliation-queue"
      }
    ]
  })
}

locals {
  service_names = [
    "wallet",
    "transaction",
    "fraud-detection",
    "notification",
    "reconciliation",
  ]
}
