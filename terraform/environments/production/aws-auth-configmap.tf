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

# Os locals (caller_arn, caller_username, is_user, is_role, account_id) 
# estão definidos em locals.tf

output "aws_auth_configmap_command" {
  description = "Comando para aplicar o ConfigMap aws-auth manualmente (se necessário)"
  value       = "kubectl apply -f k8s/aws-auth-configmap.yaml ou execute: ./scripts/apply-aws-auth.sh"
}
