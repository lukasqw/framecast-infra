variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "cluster_version" {
  description = "Versão do Kubernetes"
  type        = string
  default     = "1.28"
}

variable "cluster_role_arn" {
  description = "ARN da role do cluster EKS"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets para o cluster"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs dos security groups"
  type        = list(string)
  default     = []
}

variable "endpoint_private_access" {
  description = "Habilitar acesso privado ao endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Habilitar acesso público ao endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs permitidos para acesso público"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "authentication_mode" {
  description = "Modo de autenticação do cluster"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "enabled_cluster_log_types" {
  description = "Tipos de logs habilitados"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "node_group_name" {
  description = "Nome do node group"
  type        = string
}

variable "node_role_arn" {
  description = "ARN da role dos nodes"
  type        = string
}

variable "desired_size" {
  description = "Número desejado de nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Número máximo de nodes"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Número mínimo de nodes"
  type        = number
  default     = 1
}

variable "instance_types" {
  description = "Tipos de instância para os nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Tipo de capacidade (ON_DEMAND ou SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "disk_size" {
  description = "Tamanho do disco em GB"
  type        = number
  default     = 20
}

variable "max_unavailable" {
  description = "Número máximo de nodes indisponíveis durante update"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags para os recursos (incluindo FinOps)"
  type        = map(string)
  default     = {}
}

variable "node_tags" {
  description = "Tags adicionais específicas para os nodes"
  type        = map(string)
  default     = {}
}
