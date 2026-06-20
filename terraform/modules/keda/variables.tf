variable "namespace" {
  description = "Namespace Kubernetes onde o KEDA será instalado"
  type        = string
  default     = "keda"
}

variable "chart_version" {
  description = "Versão do Helm chart do KEDA"
  type        = string
  default     = "2.15.1"
}

variable "tags" {
  description = "Tags (usadas como labels nos recursos K8s)"
  type        = map(string)
  default     = {}
}
