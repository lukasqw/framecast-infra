variable "name" {
  description = "Nome do NLB"
  type        = string
}

variable "internal" {
  description = "Se o NLB é interno"
  type        = bool
  default     = false
}

variable "subnets" {
  description = "Subnets do NLB"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "asg_name" {
  description = "Nome do Auto Scaling Group para registrar no Target Group"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Habilitar proteção contra deleção"
  type        = bool
  default     = false
}

variable "enable_cross_zone_load_balancing" {
  description = "Habilitar load balancing cross-zone"
  type        = bool
  default     = false
}

variable "target_group_port" {
  description = "Porta do target group (NodePort)"
  type        = number
  default     = 30080
}

variable "health_check_healthy_threshold" {
  description = "Threshold para considerar healthy"
  type        = number
  default     = 3
}

variable "health_check_unhealthy_threshold" {
  description = "Threshold para considerar unhealthy"
  type        = number
  default     = 3
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
  description = "Códigos HTTP de sucesso para health check"
  type        = string
  default     = "200-299"
}

variable "deregistration_delay" {
  description = "Delay para deregistrar targets"
  type        = number
  default     = 30
}

variable "microservice_ports" {
  description = "NodePorts dos microsserviços expostos via NLB (porta listener = porta NodePort)"
  type = map(object({
    node_port         = number
    health_check_path = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
