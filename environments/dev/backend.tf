terraform {
  required_version = ">=1.10.0"

  backend "s3" {
    bucket       = "<state-bucket>"
    region       = "<state-bucket-region>"
    state_key    = "<state-bucket/dev/terraform.tfstate>"
    use_lockfile = true
    encrypt      = true
  }
}
