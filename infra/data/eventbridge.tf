resource "aws_cloudwatch_event_bus" "payment_events" {
  name = "${local.name_prefix}-events"

  tags = {
    Workload = local.name_prefix
  }
}

resource "aws_cloudwatch_event_rule" "transaction_confirmed" {
  name           = "${local.name_prefix}-transaction-confirmed"
  description    = "Confirmed transaction events, for user notification"
  event_bus_name = aws_cloudwatch_event_bus.payment_events.name

  event_pattern = jsonencode({
    source      = ["payment.transaction"]
    detail-type = ["TransactionConfirmed"]
  })
}

resource "aws_cloudwatch_event_rule" "fraud_detected" {
  name           = "${local.name_prefix}-fraud-detected"
  description    = "Fraud detection events, for real-time alerts"
  event_bus_name = aws_cloudwatch_event_bus.payment_events.name

  event_pattern = jsonencode({
    source      = ["payment.fraud"]
    detail-type = ["FraudAlertRaised"]
  })
}

resource "aws_cloudwatch_event_rule" "transaction_lifecycle" {
  name           = "${local.name_prefix}-transaction-lifecycle"
  description    = "All transaction lifecycle events, for reconciliation"
  event_bus_name = aws_cloudwatch_event_bus.payment_events.name

  event_pattern = jsonencode({
    source = ["payment.transaction"]
  })
}

output "event_bus_name" {
  value = aws_cloudwatch_event_bus.payment_events.name
}

output "event_bus_arn" {
  value = aws_cloudwatch_event_bus.payment_events.arn
}
