# GuardDuty and Security Hub are Landing Zone services. This stack never creates a detector or
# enables Security Hub: it (a) optionally switches on the EKS audit-log feature of the Landing
# Zone's existing detector, and (b) sends firewall alerts to Security Hub only when the Landing
# Zone reports security_hub_enabled = true (ADR-009).

variable "lambda_runtime" {
  description = "Runtime of the findings Lambda. Verify availability in af-south-1 before changing (docs/regional-availability.md)."
  type        = string
  default     = "python3.13"
}

data "aws_guardduty_detector" "landing_zone" {
  count = var.manage_guardduty_eks_audit_logs ? 1 : 0
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  count = var.manage_guardduty_eks_audit_logs ? 1 : 0

  detector_id = data.aws_guardduty_detector.landing_zone[0].id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

locals {
  firewall_findings_enabled = var.enable_firewall_findings && local.security_hub_enabled
}

data "archive_file" "firewall_findings" {
  count = local.firewall_findings_enabled ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/firewall_findings.py"
  output_path = "${path.module}/.build/firewall_findings.zip"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firewall_findings" {
  count = local.firewall_findings_enabled ? 1 : 0

  name               = "${local.name_prefix}-firewall-findings"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_cloudwatch_log_group" "firewall_findings" {
  count = local.firewall_findings_enabled ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-firewall-findings"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role_policy" "firewall_findings" {
  count = local.firewall_findings_enabled ? 1 : 0

  name = "import-firewall-findings"
  role = aws_iam_role.firewall_findings[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.firewall_findings[0].arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["securityhub:BatchImportFindings"]
        Resource = "arn:${local.partition}:securityhub:${var.primary_region}:${local.account_id}:product/${local.account_id}/default"
      },
    ]
  })
}

resource "aws_lambda_function" "firewall_findings" {
  count = local.firewall_findings_enabled ? 1 : 0

  function_name    = "${local.name_prefix}-firewall-findings"
  role             = aws_iam_role.firewall_findings[0].arn
  runtime          = var.lambda_runtime
  handler          = "firewall_findings.handler"
  filename         = data.archive_file.firewall_findings[0].output_path
  source_code_hash = data.archive_file.firewall_findings[0].output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      FIREWALL_ARN = aws_networkfirewall_firewall.zero_trust.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.firewall_findings]
}

resource "aws_lambda_permission" "firewall_findings_logs" {
  count = local.firewall_findings_enabled ? 1 : 0

  statement_id  = "AllowFirewallAlertLogSubscription"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.firewall_findings[0].function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.firewall_alert.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "firewall_alerts" {
  count = local.firewall_findings_enabled ? 1 : 0

  name            = "firewall-alerts-to-security-hub"
  log_group_name  = aws_cloudwatch_log_group.firewall_alert.name
  filter_pattern  = "{ $.event.event_type = \"alert\" }"
  destination_arn = aws_lambda_function.firewall_findings[0].arn

  depends_on = [aws_lambda_permission.firewall_findings_logs]
}
