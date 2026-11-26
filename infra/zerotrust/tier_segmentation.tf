# Pillar 3 (network): optional three-tier security groups in the Landing Zone VPC for workloads that
# are not on EKS. Every rule references another security group, never a CIDR block; there is no
# rule from web to database and no rule from the internet to an internal tier.

resource "aws_security_group" "tier" {
  for_each = var.create_tier_security_groups ? toset(["web", "app", "db"]) : toset([])

  name        = "${local.name_prefix}-${each.key}-tier"
  description = "${each.key} tier. Rules reference other security groups only."
  vpc_id      = local.vpc_id

  tags = { Name = "${local.name_prefix}-${each.key}-tier", Tier = each.key }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_to_app" {
  count = var.create_tier_security_groups ? 1 : 0

  security_group_id            = aws_security_group.tier["app"].id
  referenced_security_group_id = aws_security_group.tier["web"].id
  ip_protocol                  = "tcp"
  from_port                    = var.tier_app_port
  to_port                      = var.tier_app_port
  description                  = "Web tier to app tier on the app port only"
}

resource "aws_vpc_security_group_ingress_rule" "app_to_db" {
  count = var.create_tier_security_groups ? 1 : 0

  security_group_id            = aws_security_group.tier["db"].id
  referenced_security_group_id = aws_security_group.tier["app"].id
  ip_protocol                  = "tcp"
  from_port                    = var.tier_db_port
  to_port                      = var.tier_db_port
  description                  = "App tier to database tier on the database port only"
}

resource "aws_vpc_security_group_egress_rule" "web_to_app" {
  count = var.create_tier_security_groups ? 1 : 0

  security_group_id            = aws_security_group.tier["web"].id
  referenced_security_group_id = aws_security_group.tier["app"].id
  ip_protocol                  = "tcp"
  from_port                    = var.tier_app_port
  to_port                      = var.tier_app_port
  description                  = "Web tier egress to app tier only"
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  count = var.create_tier_security_groups ? 1 : 0

  security_group_id            = aws_security_group.tier["app"].id
  referenced_security_group_id = aws_security_group.tier["db"].id
  ip_protocol                  = "tcp"
  from_port                    = var.tier_db_port
  to_port                      = var.tier_db_port
  description                  = "App tier egress to database tier only"
}
