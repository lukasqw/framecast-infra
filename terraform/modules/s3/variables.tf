variable "bucket_raw" {
  description = "Nome do bucket S3 para vídeos originais (upload multipart presigned)"
  type        = string
}

variable "bucket_output" {
  description = "Nome do bucket S3 para ZIPs de frames gerados pelo worker"
  type        = string
}

variable "multipart_abort_days" {
  description = "Dias para abortar uploads multipart incompletos/abandonados (lifecycle rule)"
  type        = number
  default     = 7
}

variable "output_retention_days" {
  description = "Dias para expirar (deletar) os ZIPs de frames no bucket output"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
