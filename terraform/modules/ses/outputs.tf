output "email_identity_arn" {
  description = "ARN da identidade de e-mail verificada no SES"
  value       = aws_ses_email_identity.from.arn
}

output "from_email" {
  description = "Endereço de e-mail remetente verificado"
  value       = aws_ses_email_identity.from.email
}

output "domain_verification_token" {
  description = "Token DNS para verificação de domínio SES (vazio se domain não configurado)"
  value       = var.domain != "" ? aws_ses_domain_identity.domain[0].verification_token : ""
}
