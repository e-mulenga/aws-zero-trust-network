# Identifiers only. No KMS ARNs, tokens or secrets.
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.primary_region} --name ${module.eks.cluster_name}"
}

output "irsa_role_arns" {
  value = { for k, v in aws_iam_role.service_roles : k => v.arn }
}

output "name_prefix" {
  value = local.name_prefix
}

# Images are pushed to the Landing Zone shared ECR repository, one tag per service: <service>-<version>.
output "image_repository" {
  value = local.shared_ecr_urls["shared-applications"]
}

output "platform_image_repository" {
  description = "Landing Zone shared-platform repository (mirrored Istio images)"
  value       = local.shared_ecr_urls["shared-platform"]
}

output "public_subnet_ids" {
  value = local.public_subnet_ids
}

output "private_subnet_ids" {
  value = local.private_subnet_ids
}
