# Data Sources

data "aws_vpc" "main" {
  cidr_block = "172.31.0.0/16"
}

data "aws_subnets" "available" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.available.ids)
  id       = each.value
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# EKS cluster — usado pelos providers helm e kubernetes
# Só disponível após o cluster ser criado (primeiro apply usa -target=module.eks)
data "aws_eks_cluster" "cluster" {
  name = var.project_name

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.project_name

  depends_on = [module.eks]
}
