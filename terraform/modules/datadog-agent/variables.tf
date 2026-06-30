variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (ex: datadoghq.com, us5.datadoghq.com)"
  type        = string
  default     = "datadoghq.com"
}

variable "namespace" {
  description = "Namespace Kubernetes para o Datadog Agent"
  type        = string
  default     = "datadog"
}

variable "cluster_name" {
  description = "Nome do cluster EKS (usado como tag no Agent)"
  type        = string
}

variable "otlp_grpc_port" {
  description = "Porta gRPC OTLP para receber traces/métricas dos serviços"
  type        = number
  default     = 4317
}
