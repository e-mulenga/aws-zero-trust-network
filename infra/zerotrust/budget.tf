resource "aws_budgets_budget" "workload" {
  count = var.monthly_budget_usd > 0 ? 1 : 0

  name         = "${local.name_prefix}-zero-trust"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Stack$zerotrust"]
  }

  dynamic "notification" {
    for_each = length(var.budget_emails) > 0 ? [80, 100] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.budget_emails
    }
  }
}
