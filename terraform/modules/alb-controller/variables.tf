variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint do cluster EKS (para depends_on)"
  type        = string
}

variable "service_account_role_arn" {
  description = "ARN da IAM Role para o Service Account"
  type        = string
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}
