output "name_prefix" {
  value = local.name_prefix
}

output "firewall_name" {
  value = aws_networkfirewall_firewall.zero_trust.name
}

output "firewall_endpoint_id" {
  value = local.firewall_endpoint_id
}

output "firewall_alert_log_group" {
  value = aws_cloudwatch_log_group.firewall_alert.name
}

output "inspect_public_subnets" {
  value = var.inspect_public_subnets
}

output "vpc_flow_log_group" {
  description = "Landing Zone flow log group when exported, else the workload one (if enabled), else null"
  value       = try(local.lz.vpc_flow_logs.af_south_1.log_group, null) != null ? local.lz.vpc_flow_logs.af_south_1.log_group : try(aws_cloudwatch_log_group.vpc_flow[0].name, null)
}

output "dynamodb_gateway_endpoint_id" {
  value = local.dynamodb_gateway_endpoint_id
}

output "session_log_bucket" {
  value = aws_s3_bucket.session_logs.id
}

output "guardduty_detector_id" {
  description = "Landing Zone detector (only resolved when manage_guardduty_eks_audit_logs = true)"
  value       = try(data.aws_guardduty_detector.landing_zone[0].id, null)
}

output "dynamodb_streams_endpoint_url" {
  value = try(
    "https://${aws_vpc_endpoint.interface["dynamodb-streams"].dns_entry[0].dns_name}",
    "https://${local.lz.vpc_interface_endpoints.af_south_1.endpoint_dns_names["dynamodb-streams"]}",
    null
  )
}

output "primary_region" {
  value = var.primary_region
}

output "security_hub_findings_enabled" {
  value = local.firewall_findings_enabled
}

output "engineer_role_arn" {
  description = "Break-glass engineer role (null when no trusted principals are set)"
  value       = try(aws_iam_role.engineer[0].arn, null)
}

output "tier_security_group_ids" {
  value = { for k, v in aws_security_group.tier : k => v.id }
}
