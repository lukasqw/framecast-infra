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

# EKS cluster — usado pelos providers helm e kubernetes.
# Sem depends_on: lido no plan para que host/CA fiquem disponíveis ao provider.
# Pré-requisito: cluster deve existir antes do plan (garantido pelo Bootstrap EKS step).
data "aws_eks_cluster" "cluster" {
  name = var.project_name
}

