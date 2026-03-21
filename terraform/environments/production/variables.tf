# General Variables
variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "EKS-OFICINA-TECH"
}

# EKS Variables
variable "eks_cluster_version" {
  description = "Versão do Kubernetes"
  type        = string
  default     = "1.31"
}

variable "access_config" {
  description = "Configuração de acesso do EKS"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "node_group" {
  description = "Nome do node group"
  type        = string
  default     = "oficina_tech"
}

variable "instance_type" {
  description = "Tipo de instância EC2 para os nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Número desejado de nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Número máximo de nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Número mínimo de nodes"
  type        = number
  default     = 1
}

# RDS Variables
variable "db_password" {
  description = "Senha do banco de dados RDS"
  type        = string
  sensitive   = true
}

variable "rds_engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "16"
}

variable "rds_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Storage alocado em GB"
  type        = number
  default     = 20
}

variable "rds_backup_retention_period" {
  description = "Período de retenção de backup em dias"
  type        = number
  default     = 1
}

variable "rds_multi_az" {
  description = "Habilitar Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Pular snapshot final ao destruir"
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Habilitar proteção contra deleção"
  type        = bool
  default     = false
}

# AWS Academy / Lab Variables
variable "lab_role" {
  description = "ARN da LabRole (AWS Academy)"
  type        = string
  default     = ""
}

variable "principal_arn" {
  description = "ARN do principal para acesso ao EKS"
  type        = string
  default     = ""
}

variable "policy_arn" {
  description = "ARN da policy do EKS"
  type        = string
  default     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}

# FinOps Tags
variable "cost_center" {
  description = "Centro de custo para FinOps"
  type        = string
  default     = "engineering"
}

variable "business_unit" {
  description = "Unidade de negócio"
  type        = string
  default     = "technology"
}

variable "environment" {
  description = "Ambiente (production, staging, development)"
  type        = string
  default     = "production"
}

variable "owner" {
  description = "Responsável pelo recurso"
  type        = string
  default     = "devops-team"
}

variable "application" {
  description = "Nome da aplicação"
  type        = string
  default     = "oficina-tech"
}

variable "microservice" {
  description = "Nome do microserviço (ex: api, frontend, worker)"
  type        = string
  default     = "shared"
}

variable "budget_code" {
  description = "Código do orçamento"
  type        = string
  default     = ""
}

variable "expiration_date" {
  description = "Data de expiração do recurso (YYYY-MM-DD)"
  type        = string
  default     = ""
}
