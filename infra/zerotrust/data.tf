data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# ---- Landing Zone VPC, looked up by the Landing Zone's vpc_id (never by name) ----
data "aws_vpc" "workload" {
  id = local.vpc_id
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_subnet" "all" {
  for_each = toset(data.aws_subnets.all.ids)
  id       = each.value
}

data "aws_subnet" "private" {
  for_each = toset(local.private_subnet_ids)
  id       = each.value
}

data "aws_subnet" "public" {
  for_each = toset(local.public_subnet_ids)
  id       = each.value
}

# Route tables are not exported by the Landing Zone: resolve them from the subnets.
data "aws_route_table" "public" {
  for_each  = toset(local.public_subnet_ids)
  subnet_id = each.value
}

data "aws_route_table" "private" {
  for_each  = toset(local.private_subnet_ids)
  subnet_id = each.value
}

data "aws_internet_gateway" "workload" {
  filter {
    name   = "attachment.vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_eks_cluster" "workload" {
  name = "${local.name_prefix}-eks"
}

# 
data "aws_vpc_endpoint" "s3" {
  vpc_id       = local.vpc_id
  service_name = "com.amazonaws.${var.primary_region}.s3"
}

data "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = local.vpc_id
  service_name = "com.amazonaws.${var.primary_region}.dynamodb"
}

# Existing gateway endpoints in the VPC (Landing Zone or otherwise): create ours only if absent.
data "aws_vpc_endpoint" "gateway" {
  vpc_id       = data.aws_vpc.workload.id
  service_name = "com.amazonaws.${var.primary_region}.s3"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  public_route_table_ids  = toset([for rt in data.aws_route_table.public : rt.id])
  private_route_table_ids = toset([for rt in data.aws_route_table.private : rt.id])

  # One AZ-ordered private subnet per AZ for interface endpoints
  private_subnet_by_az = { for s in data.aws_subnet.private : s.availability_zone => s.id... }
  endpoint_azs         = slice(sort(keys(local.private_subnet_by_az)), 0, var.endpoint_az_count)
  endpoint_subnets     = [for az in local.endpoint_azs : local.private_subnet_by_az[az][0]]

  firewall_az         = sort(keys(local.private_subnet_by_az))[0]
  public_subnet_cidrs = sort([for s in data.aws_subnet.public : s.cidr_block])

  services = ["wallet", "transaction", "fraud-detection", "notification", "reconciliation"]

  # Endpoints the Landing Zone already provides (shape-tolerant: short or full service names)
  lz_endpoint_services = try(local.lz.vpc_interface_endpoints.af_south_1.service_names, [])
}

resource "terraform_data" "network_contract" {
  lifecycle {
    precondition {
      condition     = !var.inspect_public_subnets || length(local.public_route_table_ids) > 0
      error_message = "No public route table resolved from the Landing Zone public subnets."
    }
  }
}
