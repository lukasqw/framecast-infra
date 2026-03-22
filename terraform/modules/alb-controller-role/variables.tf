variable "oidc_provider_arn" {
  description = "ARN do OIDC provider do EKS"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL do OIDC provider do EKS"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
