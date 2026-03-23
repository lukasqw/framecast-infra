# Outputs - Production Environment

# EKS Cluster Outputs
output "eks_cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_arn" {
  description = "ARN do cluster EKS"
  value       = module.eks.cluster_arn
}

output "eks_cluster_certificate_authority" {
  description = "Certificado CA do cluster EKS"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_cluster_version" {
  description = "Versão do Kubernetes"
  value       = module.eks.cluster_version
}

output "eks_access_entries" {
  description = "Access entries configuradas no cluster"
  value = concat(
    # Current caller
    [{
      principal_arn = aws_eks_access_entry.current_caller.principal_arn
      type          = aws_eks_access_entry.current_caller.type
    }],
    # Lab access (se configurado)
    [for entry in aws_eks_access_entry.lab_access : {
      principal_arn = entry.principal_arn
      type          = entry.type
    }]
  )
}

# VPC e Networking Outputs
output "vpc_id" {
  description = "ID da VPC"
  value       = data.aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block da VPC"
  value       = data.aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "IDs das subnets"
  value       = local.filtered_subnet_ids
}

# Security Groups Outputs
output "eks_security_group_id" {
  description = "ID do security group do EKS"
  value       = module.security_groups.eks_security_group_id
}

output "eks_cluster_security_group_id" {
  description = "ID do security group auto-criado pelo EKS (usado pelo repo oficina-tech-db)"
  value       = module.eks.cluster_security_group_id
}

# NLB Outputs - Usado pelo API Gateway
output "nlb_dns_name" {
  description = "DNS do Network Load Balancer (usado pelo API Gateway)"
  value       = module.nlb.nlb_dns_name
}

output "nlb_arn" {
  description = "ARN do Network Load Balancer"
  value       = module.nlb.nlb_arn
}

output "nlb_zone_id" {
  description = "Zone ID do NLB (para Route53)"
  value       = module.nlb.nlb_zone_id
}

# General Outputs
output "aws_region" {
  description = "Região AWS"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "ID da conta AWS"
  value       = data.aws_caller_identity.current.account_id
}

# GitHub Actions Output
output "github_secrets_json" {
  description = "JSON formatado para criar GitHub Secrets"
  value = jsonencode({
    EKS_CLUSTER_NAME     = module.eks.cluster_name
    EKS_CLUSTER_ENDPOINT = module.eks.cluster_endpoint
    EKS_CLUSTER_CA       = module.eks.cluster_certificate_authority_data
    VPC_ID               = data.aws_vpc.main.id
    SUBNET_IDS           = join(",", local.filtered_subnet_ids)
    NLB_DNS_NAME         = module.nlb.nlb_dns_name
    AWS_REGION           = var.aws_region
  })
  sensitive = true
}
