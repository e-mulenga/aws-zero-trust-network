variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster. Availability in af-south-1 must be confirmed (aws eks describe-cluster-versions --region af-south-1) before apply."
  type        = string
  default     = "1.35"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "zero_trust_private_api" {
  description = "When true, the EKS API endpoint is private only (the target state)."
  type        = bool
  default     = true
}

variable "tag_landing_zone_subnets" {
  description = "Add the Kubernetes load-balancer discovery tags to the Landing Zone subnets with aws_ec2_tag (additive tags only; the subnets stay Landing Zone-owned). Set false if the Landing Zone adds these tags itself."
  type        = bool
  default     = true
}
