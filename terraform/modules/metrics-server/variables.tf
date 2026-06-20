variable "namespace" {
  description = "Namespace Kubernetes onde o metrics-server será instalado"
  type        = string
  default     = "kube-system"
}

variable "chart_version" {
  description = "Versão do Helm chart do metrics-server"
  type        = string
  default     = "3.12.1"
}
