# Pillar 1 (identity): a break-glass engineer role with mandatory fresh MFA, a short session,
# a permission boundary and an explicit Region deny. Day-to-day human access stays with Landing Zone
# Identity Center permission sets; this role exists only when trusted principals are supplied.
# The Landing Zone Access Analyzer is consumed (landing_zone.tf), never recreated.

locals {
  engineer_enabled = length(var.engineer_trusted_principal_arns) > 0
  approved_regions = [var.primary_region, var.dr_region]
}

data "aws_iam_policy_document" "permission_boundary" {
  count = local.engineer_enabled ? 1 : 0

  statement {
    sid       = "AllowScopedServices"
    effect    = "Allow"
    actions   = ["ec2:Describe*", "eks:Describe*", "eks:List*", "ssm:StartSession", "ssm:TerminateSession", "ssm:DescribeSessions", "logs:Get*", "logs:Describe*", "logs:StartQuery", "logs:GetQueryResults", "cloudwatch:Get*", "cloudwatch:List*", "cloudwatch:Describe*"]
    resources = ["*"]
  }

  statement {
    sid     = "DenyPrivilegeEscalation"
    effect  = "Deny"
    actions = ["iam:CreateUser", "iam:CreateAccessKey", "iam:AttachUserPolicy", "iam:PutUserPolicy", "iam:CreatePolicyVersion", "iam:SetDefaultPolicyVersion", "iam:PutRolePermissionsBoundary", "iam:DeleteRolePermissionsBoundary", "organizations:*"]

    resources = ["*"]
  }

  statement {
    sid       = "DenyOutsideApprovedRegions"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = local.approved_regions
    }
  }
}

resource "aws_iam_policy" "permission_boundary" {
  count = local.engineer_enabled ? 1 : 0

  name        = "${local.name_prefix}-permission-boundary"
  description = "Caps the engineer role: read and session access only, no privilege escalation, approved Regions only."
  policy      = data.aws_iam_policy_document.permission_boundary[0].json
}

data "aws_iam_policy_document" "engineer_trust" {
  count = local.engineer_enabled ? 1 : 0

  statement {
    sid     = "RequireFreshMfa"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.engineer_trusted_principal_arns
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "aws:MultiFactorAuthAge"
      values   = ["3600"]
    }
  }
}

resource "aws_iam_role" "engineer" {
  count = local.engineer_enabled ? 1 : 0

  name                 = "${local.name_prefix}-engineer"
  max_session_duration = var.engineer_session_seconds
  permissions_boundary = aws_iam_policy.permission_boundary[0].arn
  assume_role_policy   = data.aws_iam_policy_document.engineer_trust[0].json
}

data "aws_iam_policy_document" "engineer" {
  count = local.engineer_enabled ? 1 : 0

  statement {
    sid       = "ReadWorkload"
    effect    = "Allow"
    actions   = ["ec2:Describe*", "eks:DescribeCluster", "eks:ListClusters", "logs:Describe*", "logs:Get*", "cloudwatch:Get*", "cloudwatch:List*"]
    resources = ["*"]
  }

  # Sessions only to instances of this workload's cluster.
  statement {
    sid       = "StartSessionOnWorkloadNodes"
    effect    = "Allow"
    actions   = ["ssm:StartSession"]
    resources = ["arn:${local.partition}:ec2:*:${local.account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = ["aws-zero-trust-network"]
    }
  }

  statement {
    sid       = "EndOwnSessions"
    effect    = "Allow"
    actions   = ["ssm:TerminateSession", "ssm:ResumeSession"]
    resources = ["arn:${local.partition}:ssm:*:*:session/$${aws:username}-*"]
  }
}

resource "aws_iam_role_policy" "engineer" {
  count = local.engineer_enabled ? 1 : 0

  name   = "scoped-access"
  role   = aws_iam_role.engineer[0].id
  policy = data.aws_iam_policy_document.engineer[0].json
}
