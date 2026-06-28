# General Variables
variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto — usado como prefixo em todos os recursos (ex: cluster EKS, NLB, SGs)"
  type        = string
  default     = "framecast"
}

# EKS Variables
variable "eks_cluster_version" {
  description = "Versão do Kubernetes"
  type        = string
  default     = "1.31"
}

variable "access_config" {
  description = "Modo de autenticação do EKS (API = Access Entries, CONFIG_MAP = ConfigMap, API_AND_CONFIG_MAP = ambos)"
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "CONFIG_MAP", "API_AND_CONFIG_MAP"], var.access_config)
    error_message = "access_config deve ser 'API', 'CONFIG_MAP' ou 'API_AND_CONFIG_MAP'."
  }
}

variable "node_group" {
  description = "Nome do node group EKS"
  type        = string
  default     = "framecast"
}

variable "instance_type" {
  description = "Tipo de instância EC2 para os nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Número desejado de nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Número máximo de nodes"
  type        = number
  default     = 3
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
  description = "ARN do principal adicional para acesso ao EKS"
  type        = string
  default     = ""
}

variable "policy_arn" {
  description = "ARN da policy de acesso ao EKS"
  type        = string
  default     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}

# EKS Access Configuration
variable "additional_users" {
  description = "Usuários IAM adicionais para acesso ao cluster"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "additional_roles" {
  description = "Roles IAM adicionais para acesso ao cluster"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

# S3
variable "s3_bucket_raw" {
  description = "Nome do bucket S3 para vídeos originais (upload multipart presigned)"
  type        = string
  default     = "framecast-videos-raw"
}

variable "s3_bucket_output" {
  description = "Nome do bucket S3 para ZIPs de frames gerados pelo worker"
  type        = string
  default     = "framecast-videos-output"
}

variable "s3_multipart_abort_days" {
  description = "Dias para abortar uploads multipart incompletos (lifecycle rule no bucket raw)"
  type        = number
  default     = 3
}

# SES
variable "ses_from_email" {
  description = "E-mail remetente verificado no SES (worker usa para notificações)"
  type        = string
  default     = "noreply@framecast.app"
}

variable "ses_domain" {
  description = "Domínio opcional para verificação SES (vazio = só verifica o e-mail)"
  type        = string
  default     = ""
}

variable "enable_ses" {
  description = "Provisionar identidade SES (requer ses:VerifyEmailIdentity — desabilitar na AWS Academy/LabRole)"
  type        = bool
  default     = false
}

# SQS
variable "sqs_visibility_timeout" {
  description = "Visibility timeout da fila (segundos) — deve cobrir o lease+heartbeat do worker (900s = 15min)"
  type        = number
  default     = 900
}

variable "sqs_max_receive_count" {
  description = "Máximo de tentativas antes de mover para DLQ"
  type        = number
  default     = 3
}

variable "sqs_retention_seconds" {
  description = "Retenção de mensagens na fila (segundos)"
  type        = number
  default     = 1209600 # 14 dias
}

# Controllers (Helm)
variable "enable_keda" {
  description = "Instalar KEDA para auto-scaling do worker por comprimento de fila SQS"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Instalar metrics-server para HPA baseado em CPU/memória"
  type        = bool
  default     = true
}

variable "enable_datadog_agent" {
  description = "Instalar Datadog Agent DaemonSet com receptor OTLP gRPC habilitado"
  type        = bool
  default     = false
}

# Datadog Variables
variable "datadog_api_key" {
  description = "Datadog API key (monitors, dashboards e Agent)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_app_key" {
  description = "Datadog Application key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_api_url" {
  description = "Datadog API URL"
  type        = string
  default     = "https://api.datadoghq.com/"
}

# FinOps Tags
variable "cost_center" {
  description = "Centro de custo FinOps"
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
  default     = "framecast"
}

variable "microservice" {
  description = "Microserviço/componente"
  type        = string
  default     = "shared"
}

variable "budget_code" {
  description = "Código do orçamento (opcional)"
  type        = string
  default     = ""
}

variable "expiration_date" {
  description = "Data de expiração do recurso YYYY-MM-DD (opcional)"
  type        = string
  default     = ""
}
