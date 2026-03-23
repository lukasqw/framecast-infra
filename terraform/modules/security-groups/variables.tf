variable "name_prefix" {
  description = "Prefixo para os nomes dos security groups"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
