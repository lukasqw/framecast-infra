# EKS Access Configuration
# Este arquivo gerencia o acesso ao cluster EKS usando EKS Access Entries API

# Access Entry para o usuário/role atual (detectado automaticamente)
# Usa local.caller_arn que já converte assumed-role para role ARN
resource "aws_eks_access_entry" "current_caller" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = local.caller_arn
  kubernetes_groups = []
  type              = "STANDARD"

  depends_on = [module.eks]
}

# Policy Association para o usuário/role atual
resource "aws_eks_access_policy_association" "current_caller_policy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = local.caller_arn
  policy_arn    = var.policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.current_caller]
}

# Access Entry para o principal configurado manualmente (se fornecido)
resource "aws_eks_access_entry" "lab_access" {
  count = var.principal_arn != "" && var.principal_arn != local.caller_arn ? 1 : 0

  cluster_name      = module.eks.cluster_name
  principal_arn     = var.principal_arn
  kubernetes_groups = []
  type              = "STANDARD"

  depends_on = [module.eks]
}

# Policy Association para o principal configurado manualmente
resource "aws_eks_access_policy_association" "lab_policy" {
  count = var.principal_arn != "" && var.principal_arn != local.caller_arn ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = var.principal_arn
  policy_arn    = var.policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.lab_access]
}
