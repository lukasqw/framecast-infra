# Outputs — Production Environment
# Consumidos por framecast-db e framecast-gateway via terraform_remote_state

# ── EKS ────────────────────────────────────────────────────────────────────

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
  description = "Versão do Kubernetes em uso"
  value       = module.eks.cluster_version
}

output "eks_access_entries" {
  description = "Access entries configuradas no cluster"
  value = concat(
    [{
      principal_arn = aws_eks_access_entry.current_caller.principal_arn
      type          = aws_eks_access_entry.current_caller.type
    }],
    [for entry in aws_eks_access_entry.lab_access : {
      principal_arn = entry.principal_arn
      type          = entry.type
    }]
  )
}

# ── Rede ───────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID da VPC"
  value       = data.aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block da VPC"
  value       = data.aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "IDs das subnets (us-east-1a, us-east-1b)"
  value       = local.filtered_subnet_ids
}

output "eks_security_group_id" {
  description = "ID do security group do EKS (módulo security-groups)"
  value       = module.security_groups.eks_security_group_id
}

output "eks_cluster_security_group_id" {
  description = "ID do security group auto-criado pelo EKS (consumido por framecast-db)"
  value       = module.eks.cluster_security_group_id
}

# ── NLB — consumido por framecast-gateway ──────────────────────────────────

output "nlb_dns_name" {
  description = "DNS do Network Load Balancer"
  value       = module.nlb.nlb_dns_name
}

output "nlb_arn" {
  description = "ARN do Network Load Balancer"
  value       = module.nlb.nlb_arn
}

output "nlb_zone_id" {
  description = "Zone ID do NLB (para Route53 no framecast-gateway)"
  value       = module.nlb.nlb_zone_id
}

# ── SQS ────────────────────────────────────────────────────────────────────

output "sqs_queue_url" {
  description = "URL da fila SQS framecast-processing (outbox dispatcher → worker)"
  value       = aws_sqs_queue.processing.url
}

output "sqs_queue_arn" {
  description = "ARN da fila SQS (usado pelo ScaledObject do KEDA)"
  value       = aws_sqs_queue.processing.arn
}

output "sqs_dlq_url" {
  description = "URL da DLQ framecast-processing-dlq"
  value       = aws_sqs_queue.dlq.url
}

output "sqs_dlq_arn" {
  description = "ARN da DLQ"
  value       = aws_sqs_queue.dlq.arn
}

# ── S3 ─────────────────────────────────────────────────────────────────────

output "s3_bucket_raw" {
  description = "Nome do bucket S3 de vídeos originais (injetar em api/worker via env)"
  value       = module.s3.bucket_raw
}

output "s3_bucket_raw_arn" {
  description = "ARN do bucket S3 raw"
  value       = module.s3.bucket_raw_arn
}

output "s3_bucket_output" {
  description = "Nome do bucket S3 de ZIPs de frames (injetar em api/worker via env)"
  value       = module.s3.bucket_output
}

output "s3_bucket_output_arn" {
  description = "ARN do bucket S3 output"
  value       = module.s3.bucket_output_arn
}

# ── SES ────────────────────────────────────────────────────────────────────

output "ses_from_identity" {
  description = "E-mail remetente verificado no SES"
  value       = var.enable_ses ? module.ses[0].from_email : var.ses_from_email
}

output "ses_from_identity_arn" {
  description = "ARN da identidade SES"
  value       = var.enable_ses ? module.ses[0].email_identity_arn : ""
}

# ── Geral ──────────────────────────────────────────────────────────────────

output "aws_region" {
  description = "Região AWS"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "ID da conta AWS"
  value       = data.aws_caller_identity.current.account_id
}

output "current_caller_info" {
  description = "Debug: ARN/usuário que executou o Terraform"
  value = {
    raw_arn  = local.raw_caller_arn
    arn      = local.caller_arn
    username = local.caller_username
    type     = local.is_user ? "user" : (local.is_role ? "role" : "unknown")
    account  = local.account_id
    note     = local.is_assumed_role ? "Converted from assumed-role to role ARN" : "Using original ARN"
  }
}

# JSON com todos os outputs relevantes para configurar GitHub Secrets nos repos de app
output "github_secrets_json" {
  description = "JSON formatado para criar GitHub Secrets em framecast-api e framecast-worker"
  value = jsonencode({
    EKS_CLUSTER_NAME     = module.eks.cluster_name
    EKS_CLUSTER_ENDPOINT = module.eks.cluster_endpoint
    EKS_CLUSTER_CA       = module.eks.cluster_certificate_authority_data
    VPC_ID               = data.aws_vpc.main.id
    SUBNET_IDS           = join(",", local.filtered_subnet_ids)
    NLB_DNS_NAME         = module.nlb.nlb_dns_name
    SQS_QUEUE_URL        = aws_sqs_queue.processing.url
    S3_BUCKET_RAW        = module.s3.bucket_raw
    S3_BUCKET_OUTPUT     = module.s3.bucket_output
    SES_FROM_EMAIL       = var.enable_ses ? module.ses[0].from_email : var.ses_from_email
    AWS_REGION           = var.aws_region
  })
  sensitive = true
}
