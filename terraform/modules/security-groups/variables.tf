variable "name_prefix" {
  description = "Prefixo para os nomes dos security groups"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
}

variable "rds_port" {
  description = "Porta do RDS"
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
