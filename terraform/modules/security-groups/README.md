# Security Groups Module

Módulo Terraform para criar security groups para EKS, RDS e ALB.

## Recursos Criados

- Security Group para EKS
- Security Group para RDS
- Security Group para ALB
- Regras de ingress e egress

## Uso

```hcl
module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix = "my-project"
  vpc_id      = data.aws_vpc.main.id
  vpc_cidr    = data.aws_vpc.main.cidr_block

  rds_port = 5432

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
