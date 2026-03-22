# EKS Access Configuration
# Este arquivo gerencia o acesso ao cluster EKS usando EKS Access Entries API

# Access Entry para o usuário/role atual (detectado automaticamente)
resource "aws_eks_access_entry" "current_caller" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_caller_identity.current.arn
  kubernetes_groups = []
  type              = "STANDARD"

  depends_on = [module.eks]
}

# Policy Association para o usuário/role atual
resource "aws_eks_access_policy_association" "current_caller_policy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = var.policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.current_caller]
}

# Access Entry para o principal configurado manualmente (se fornecido)
resource "aws_eks_access_entry" "lab_access" {
  count = var.principal_arn != "" && var.principal_arn != data.aws_caller_identity.current.arn ? 1 : 0

  cluster_name      = module.eks.cluster_name
  principal_arn     = var.principal_arn
  kubernetes_groups = []
  type              = "STANDARD"

  depends_on = [module.eks]
}

# Policy Association para o principal configurado manualmente
resource "aws_eks_access_policy_association" "lab_policy" {
  count = var.principal_arn != "" && var.principal_arn != data.aws_caller_identity.current.arn ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = var.principal_arn
  policy_arn    = var.policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.lab_access]
}

# Access Entries para usuários adicionais
resource "aws_eks_access_entry" "additional_users" {
  for_each = { for idx, user in var.additional_users : idx => user }

  cluster_name      = module.eks.cluster_name
  principal_arn     = each.value.userarn
  kubernetes_groups = each.value.groups
  type              = "STANDARD"

  depends_on = [module.eks]
}

# Policy Association para usuários adicionais (admin)
resource "aws_eks_access_policy_association" "additional_users_admin" {
  for_each = {
    for idx, user in var.additional_users :
    idx => user
    if contains(user.groups, "system:masters")
  }

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value.userarn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.additional_users]
}

# Access Entries para roles adicionais
resource "aws_eks_access_entry" "additional_roles" {
  for_each = { for idx, role in var.additional_roles : idx => role }

  cluster_name      = module.eks.cluster_name
  principal_arn     = each.value.rolearn
  kubernetes_groups = each.value.groups
  type              = "STANDARD"

  depends_on = [module.eks]
}

# Policy Association para roles adicionais (admin)
resource "aws_eks_access_policy_association" "additional_roles_admin" {
  for_each = {
    for idx, role in var.additional_roles :
    idx => role
    if contains(role.groups, "system:masters")
  }

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value.rolearn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.additional_roles]
}
