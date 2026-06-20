variable "from_email" {
  description = "Endereço de e-mail remetente verificado no SES (ex: noreply@framecast.app)"
  type        = string
}

variable "domain" {
  description = "Domínio para verificação SES (opcional; se vazio só verifica o e-mail)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
