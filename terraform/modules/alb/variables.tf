variable "name" {
  description = "Nome do ALB"
  type        = string
}

variable "internal" {
  description = "Se o ALB é interno"
  type        = bool
  default     = false
}

variable "security_groups" {
  description = "Security groups do ALB"
  type        = list(string)
}

variable "subnets" {
  description = "Subnets do ALB"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Habilitar proteção contra deleção"
  type        = bool
  default     = false
}

variable "enable_http2" {
  description = "Habilitar HTTP/2"
  type        = bool
  default     = true
}

variable "enable_cross_zone_load_balancing" {
  description = "Habilitar load balancing cross-zone"
  type        = bool
  default     = false
}

variable "target_group_port" {
  description = "Porta do target group"
  type        = number
  default     = 80
}

variable "target_group_protocol" {
  description = "Protocolo do target group"
  type        = string
  default     = "HTTP"
}

variable "target_type" {
  description = "Tipo de target (instance, ip, lambda)"
  type        = string
  default     = "ip"
}

variable "health_check_healthy_threshold" {
  description = "Threshold para considerar healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Threshold para considerar unhealthy"
  type        = number
  default     = 2
}

variable "health_check_timeout" {
  description = "Timeout do health check"
  type        = number
  default     = 5
}

variable "health_check_interval" {
  description = "Intervalo do health check"
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "Path do health check"
  type        = string
  default     = "/"
}

variable "health_check_matcher" {
  description = "Códigos HTTP de sucesso"
  type        = string
  default     = "200-299"
}

variable "deregistration_delay" {
  description = "Delay para deregistrar targets"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
