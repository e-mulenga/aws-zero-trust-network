# AWS API calls from the workload stay on the AWS network. Endpoints are created only when the
# Landing Zone (or an existing endpoint in the VPC) does not already provide them.
# Interface endpoints are chosen from the calls the workload actually makes (ADR-008).

locals {
  gateway_to_create = {
    for svc in ["dynamodb", "s3"] :
    svc => svc
    if var.create_workload_endpoints
  }

  interface_endpoints = {
    "ecr.api"          = "ECR API (image manifests)"
    "ecr.dkr"          = "ECR registry (image pulls)"
    "ec2"              = "EC2 API (VPC CNI)"
    "sts"              = "STS (IRSA web identity)"
    "events"           = "EventBridge (transaction events)"
    "sqs"              = "SQS (notification and reconciliation queues)"
    "dynamodb-streams" = "DynamoDB Streams (fraud detection)"
    "ssm"              = "Systems Manager"
    "ssmmessages"      = "Session Manager data channel"
    "ec2messages"      = "Systems Manager agent messages"
  }

  interface_to_create = {
    for k, purpose in local.interface_endpoints :
    k => purpose
    if var.create_workload_endpoints && !anytrue([for n in local.lz_endpoint_services : n == k || endswith(n, ".${k}")])
  }

  dynamodb_gateway_endpoint_id = try(
    aws_vpc_endpoint.gateway["dynamodb"].id,
    data.aws_vpc_endpoint.gateway.id,
    null
  )
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_to_create

  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.primary_region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.private_route_table_ids

  tags = {
    Name = "${local.name_prefix}-${each.key}"
  }

  depends_on = [terraform_data.network_contract]
}

resource "aws_security_group" "endpoints" {
  count = length(local.interface_to_create) > 0 ? 1 : 0

  name        = "${local.name_prefix}-vpc-endpoints"
  description = "HTTPS from inside the VPC to the interface endpoints"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.name_prefix}-vpc-endpoints"
  }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  count = length(local.interface_to_create) > 0 ? 1 : 0

  security_group_id = aws_security_group.endpoints[0].id
  description       = "HTTPS from the VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = local.vpc_cidr
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_to_create

  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.primary_region}.${each.key}"
  vpc_endpoint_type = "Interface"

  # DynamoDB Streams interface endpoints have no private DNS name: the fraud detection
  # service is pointed at the endpoint's own DNS name (AWS_ENDPOINT_URL_DYNAMODB_STREAMS).
  private_dns_enabled = each.key != "dynamodb-streams"
  subnet_ids          = local.endpoint_subnets
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = {
    Name    = "${local.name_prefix}-${each.key}"
    Purpose = each.value
  }

  depends_on = [terraform_data.network_contract]
}
