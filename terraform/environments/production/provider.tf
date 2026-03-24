# Provider Configuration
provider "aws" {
  region = var.aws_region

  # Removed default_tags to avoid conflicts with security group rules
  # Tags are applied directly in each resource instead
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = var.datadog_api_url
}
