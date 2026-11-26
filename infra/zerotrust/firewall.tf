# One inspected path in and out of the Landing Zone VPC.
#
# Internet -> IGW -> (edge route table) -> firewall endpoint -> public subnets
# Public subnets -> 0.0.0.0/1 and 128.0.0.0/1 -> firewall endpoint -> firewall subnet -> IGW
#
# The firewall, its subnet, route tables, policy and logs are NEW resources owned by this stack.
# Routing INTO Landing Zone route tables is the only touch of Landing Zone resources, and it is
# off unless inspect_public_subnets = true (ADR-007, docs/landing-zone-integration.md).

resource "aws_subnet" "firewall" {
  vpc_id                  = local.vpc_id
  cidr_block              = var.firewall_subnet_cidr
  availability_zone       = local.firewall_az
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-firewall-${local.firewall_az}"
  }

  depends_on = [terraform_data.network_contract]
}

resource "aws_route_table" "firewall" {
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.workload.id
  }

  tags = {
    Name = "${local.name_prefix}-firewall"
  }
}

resource "aws_route_table_association" "firewall" {
  subnet_id      = aws_subnet.firewall.id
  route_table_id = aws_route_table.firewall.id
}

resource "aws_networkfirewall_rule_group" "zero_trust" {
  name     = "${local.name_prefix}-zero-trust"
  type     = "STATEFUL"
  capacity = 100

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = [local.vpc_cidr]
        }
      }
    }

    rules_source {
      rules_string = templatefile("${path.module}/rules/zero-trust.rules.tftpl", {
        allowed_domains = var.egress_allowed_domains
      })
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "zero_trust" {
  name = "${local.name_prefix}-zero-trust"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    # Default deny, logged. The app-layer variants let a segmented TLS Client Hello through until
    # its SNI is visible so the domain allowlist can be evaluated.
    stateful_default_actions = ["aws:drop_established_app_layer", "aws:alert_established_app_layer"]

    stateful_rule_group_reference {
      priority     = 100
      resource_arn = aws_networkfirewall_rule_group.zero_trust.arn
    }
  }
}

resource "aws_networkfirewall_firewall" "zero_trust" {
  name                = "${local.name_prefix}-zero-trust"
  vpc_id              = local.vpc_id
  firewall_policy_arn = aws_networkfirewall_firewall_policy.zero_trust.arn

  delete_protection                 = var.enable_deletion_protection
  subnet_change_protection          = var.enable_deletion_protection
  firewall_policy_change_protection = var.enable_deletion_protection

  subnet_mapping {
    subnet_id = aws_subnet.firewall.id
  }
}

locals {
  firewall_endpoint_id = one([
    for s in aws_networkfirewall_firewall.zero_trust.firewall_status[0].sync_states :
    s.attachment[0].endpoint_id
  ])

  # Cartesian product: every Landing Zone public route table x both /1 prefixes
  public_inspection_routes = var.inspect_public_subnets ? {
    for pair in setproduct(local.public_route_table_ids, ["0.0.0.0/1", "128.0.0.0/1"]) :
    "${pair[0]}|${pair[1]}" => { route_table_id = pair[0], cidr = pair[1] }
  } : {}
}

# Ingress routing (gated): traffic arriving at the IGW for the public subnets goes to the firewall first.
resource "aws_route_table" "igw_edge" {
  count  = var.inspect_public_subnets ? 1 : 0
  vpc_id = local.vpc_id

  tags = {
    Name = "${local.name_prefix}-igw-edge"
  }
}

resource "aws_route" "igw_edge_to_firewall" {
  for_each = var.inspect_public_subnets ? toset(local.public_subnet_cidrs) : toset([])

  route_table_id         = aws_route_table.igw_edge[0].id
  destination_cidr_block = each.value
  vpc_endpoint_id        = local.firewall_endpoint_id
}

resource "aws_route_table_association" "igw_edge" {
  count = var.inspect_public_subnets ? 1 : 0

  gateway_id     = data.aws_internet_gateway.workload.id
  route_table_id = aws_route_table.igw_edge[0].id
}

# Return and egress path (gated): ADDS routes to Landing Zone-owned public route tables.
resource "aws_route" "public_to_firewall" {
  for_each = local.public_inspection_routes

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.cidr
  vpc_endpoint_id        = local.firewall_endpoint_id
}

resource "aws_cloudwatch_log_group" "firewall_alert" {
  name              = "/${local.name_prefix}/network-firewall/alert"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "firewall_flow" {
  name              = "/${local.name_prefix}/network-firewall/flow"
  retention_in_days = var.log_retention_days
}

resource "aws_networkfirewall_logging_configuration" "zero_trust" {
  firewall_arn = aws_networkfirewall_firewall.zero_trust.arn

  logging_configuration {
    log_destination_config {
      log_type             = "ALERT"
      log_destination_type = "CloudWatchLogs"
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_alert.name
      }
    }

    log_destination_config {
      log_type             = "FLOW"
      log_destination_type = "CloudWatchLogs"
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_flow.name
      }
    }
  }
}
