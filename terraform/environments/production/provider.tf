# Provider Configuration
provider "aws" {
  region = var.aws_region

  # Removed default_tags to avoid conflicts with security group rules
  # Tags are applied directly in each resource instead
}
