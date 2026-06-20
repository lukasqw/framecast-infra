# SES — identidade verificada para envio de e-mails pelo worker

resource "aws_ses_email_identity" "from" {
  email = var.from_email
}

# Verificação de domínio (opcional)
resource "aws_ses_domain_identity" "domain" {
  count  = var.domain != "" ? 1 : 0
  domain = var.domain
}
