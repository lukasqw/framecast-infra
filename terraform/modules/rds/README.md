# RDS Module

Módulo Terraform para provisionar uma instância Amazon RDS PostgreSQL.

## Recursos Criados

- RDS Instance
- DB Subnet Group

## Uso

```hcl
module "rds" {
  source = "../../modules/rds"

  identifier     = "my-postgres-db"
  engine_version = "16"
  instance_class = "db.t3.micro"

  database_name = "myapp"
  username      = "dbadmin"
  password      = var.db_password

  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.security_groups.rds_security_group_id]

  allocated_storage       = 20
  backup_retention_period = 7
  multi_az                = false

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
