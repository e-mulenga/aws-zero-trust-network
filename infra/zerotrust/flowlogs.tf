# VPC Flow Logs belong to the Landing Zone. The Landing Zone currently exports none
# (vpc_flow_logs.af_south_1.flow_log_ids = []), but this stack still does NOT create them by
# default. Set enable_workload_flow_logs = true only to capture the "private AWS service call
# proof" evidence, and only while the Landing Zone has no flow log on this VPC (checked below).
# v5 fields: pkt-dst-aws-service names the AWS service, traffic-path 7 = gateway endpoint, 8 = IGW.

variable "enable_workload_flow_logs" {
  description = "Create a workload flow log for the private-path proof. Refused if the Landing Zone already exports flow logs."
  type        = bool
  default     = false
}

locals {
  lz_flow_log_ids = try(local.lz.vpc_flow_logs.af_south_1.flow_log_ids, [])
}

resource "terraform_data" "flow_log_guard" {
  count = var.enable_workload_flow_logs ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.lz_flow_log_ids) == 0
      error_message = "The Landing Zone already provides VPC flow logs; do not duplicate them. Set enable_workload_flow_logs = false."
    }
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
  count = var.enable_workload_flow_logs ? 1 : 0

  name              = "/${local.name_prefix}/vpc-flow-logs"
  retention_in_days = var.log_retention_days

  depends_on = [terraform_data.flow_log_guard]
}

data "aws_iam_policy_document" "flow_logs_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_workload_flow_logs ? 1 : 0

  name               = "${local.name_prefix}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_trust.json
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_workload_flow_logs ? 1 : 0

  name = "write-vpc-flow-logs"
  role = aws_iam_role.flow_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.vpc_flow[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "workload" {
  count = var.enable_workload_flow_logs ? 1 : 0

  vpc_id                   = local.vpc_id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow[0].arn
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  max_aggregation_interval = 60

  log_format = join(" ", [
    "$${version}", "$${interface-id}", "$${srcaddr}", "$${dstaddr}", "$${srcport}", "$${dstport}",
    "$${protocol}", "$${packets}", "$${bytes}", "$${start}", "$${end}", "$${action}", "$${log-status}",
    "$${subnet-id}", "$${pkt-srcaddr}", "$${pkt-dstaddr}", "$${pkt-dst-aws-service}",
    "$${flow-direction}", "$${traffic-path}",
  ])
}
