# AWS Auth ConfigMap - Configuração Automática
# Este arquivo gerencia o ConfigMap aws-auth do Kubernetes automaticamente
# detectando o usuário/role atual que está executando o Terraform

# NOTA: O ConfigMap aws-auth NÃO é criado via Terraform para evitar problemas
# de "chicken and egg" (precisa de acesso ao cluster para criar o ConfigMap).
# 
# Em vez disso, usamos EKS Access Entries (método moderno) que não requer
# acesso ao cluster para ser configurado.
#
# Se você realmente precisa do ConfigMap, aplique manualmente após criar o cluster:
# ./scripts/apply-aws-auth.sh

# Extrair o nome do usuário/role do ARN
locals {
  # ARN completo do caller
  caller_arn = data.aws_caller_identity.current.arn
  
  # Extrair username do ARN
  # Exemplo: arn:aws:iam::123456789:user/awsstudent -> awsstudent
  # Exemplo: arn:aws:iam::123456789:role/LabRole -> LabRole
  caller_username = element(split("/", local.caller_arn), length(split("/", local.caller_arn)) - 1)
  
  # Determinar se é user ou role
  is_user = can(regex(":user/", local.caller_arn))
  is_role = can(regex(":role/", local.caller_arn))
  
  # Account ID
  account_id = data.aws_caller_identity.current.account_id
}

# Output para debug
output "current_caller_info" {
  description = "Informações do usuário/role atual executando o Terraform"
  value = {
    arn      = local.caller_arn
    username = local.caller_username
    type     = local.is_user ? "user" : (local.is_role ? "role" : "unknown")
    account  = local.account_id
  }
}

output "aws_auth_configmap_command" {
  description = "Comando para aplicar o ConfigMap aws-auth manualmente (se necessário)"
  value       = "kubectl apply -f k8s/aws-auth-configmap.yaml ou execute: ./scripts/apply-aws-auth.sh"
}
