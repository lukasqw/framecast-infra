# AWS Auth ConfigMap - Configuração Automática
# Este arquivo gerencia o ConfigMap aws-auth do Kubernetes automaticamente
# detectando o usuário/role atual que está executando o Terraform

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

# ConfigMap aws-auth
resource "kubernetes_config_map_v1_data" "aws_auth" {
  # Só criar se o modo de autenticação incluir CONFIG_MAP
  count = var.access_config == "CONFIG_MAP" || var.access_config == "API_AND_CONFIG_MAP" ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    # Roles IAM (para nodes do EKS + roles adicionais)
    mapRoles = yamlencode(
      concat(
        # LabRole para nodes
        [
          {
            rolearn  = local.lab_role_arn
            username = "system:node:{{EC2PrivateDNSName}}"
            groups = [
              "system:bootstrappers",
              "system:nodes"
            ]
          }
        ],
        # Role atual se for role (não user)
        local.is_role ? [
          {
            rolearn  = local.caller_arn
            username = local.caller_username
            groups   = ["system:masters"]
          }
        ] : [],
        # Roles adicionais configuradas manualmente
        [
          for role in var.additional_roles : {
            rolearn  = role.rolearn
            username = role.username
            groups   = role.groups
          }
        ]
      )
    )

    # Usuários IAM (detectado automaticamente + adicionais)
    mapUsers = yamlencode(
      concat(
        # Usuário atual se for user (não role)
        local.is_user ? [
          {
            userarn  = local.caller_arn
            username = local.caller_username
            groups   = ["system:masters"]
          }
        ] : [],
        # Usuários adicionais configurados manualmente
        [
          for user in var.additional_users : {
            userarn  = user.userarn
            username = user.username
            groups   = user.groups
          }
        ]
      )
    )
  }

  force = true

  depends_on = [
    module.eks,
    aws_eks_access_entry.lab_access,
    aws_eks_access_policy_association.lab_policy
  ]
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

output "aws_auth_applied" {
  description = "Indica se o ConfigMap aws-auth foi aplicado"
  value       = var.access_config == "CONFIG_MAP" || var.access_config == "API_AND_CONFIG_MAP"
}
