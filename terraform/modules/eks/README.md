# EKS Module

Módulo Terraform para provisionar um cluster Amazon EKS com node group.

## Recursos Criados

- EKS Cluster
- EKS Node Group

## Uso

```hcl
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"
  cluster_role_arn = aws_iam_role.eks_cluster.arn
  node_role_arn    = aws_iam_role.eks_nodes.arn

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.eks_security_group_id]

  node_group_name = "main-nodes"
  desired_size    = 2
  max_size        = 3
  min_size        = 1
  instance_types  = ["t3.medium"]

  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

## Variáveis

Ver `variables.tf` para lista completa de variáveis configuráveis.

## Outputs

Ver `outputs.tf` para lista completa de outputs disponíveis.
