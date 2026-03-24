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
  description = "Configuração de acesso do EKS (API = apenas Access Entries, CONFIG_MAP = apenas ConfigMap, API_AND_CONFIG_MAP = ambos)"
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "CONFIG_MAP", "API_AND_CONFIG_MAP"], var.access_config)
    error_message = "access_config deve ser 'API', 'CONFIG_MAP' ou 'API_AND_CONFIG_MAP'"
  }
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

# EKS Access Configuration
variable "additional_users" {
  description = "Lista de usuários IAM adicionais para acesso ao cluster"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "additional_roles" {
  description = "Lista de roles IAM adicionais para acesso ao cluster"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
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

# Datadog Variables
variable "datadog_api_key" {
  description = "Datadog API key para monitors e alertas"
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_app_key" {
  description = "Datadog Application key para monitors e alertas"
  type        = string
  sensitive   = true
  default     = ""
}
